////////////////////////////////////////////////////////////////////
//                                                                //
//   d8888   o888                                                 //
//  d888888  O888                                ,--.""           //
//       88   88  V888888                __,----( o ))            //
//       88  88      88P               ,'--.      , (             //
//       88 88     88P          -"",:-(    o ),-'/  ;             //
//       8888    d8P              ( o) `o  _,'\ / ;(              //
//       888    888888888P         `-;_-<'\_|-'/ '  )             //
//                                     `.`-.__/ '   |             //
//                        \`.            `. .__,   ;              //
//                         )_;--.         \`       |              //
//                        /'(__,-:         )      ;               //
//                      ;'    (_,-:     _,::     .|               //
//                     ;       ( , ) _,':::'    ,;                //
//                    ;         )-,;'  `:'     .::                //
//                    |         `'  ;         `:::\               //
//                    :       ,'    '            `:\              //
//                    ;:    '  _,-':         .'     `-.           //
//                     ';::..,'  ' ,        `   ,__    `.         //
//                       `;''   / ;           _;_,-'     `.       //
//                             /            _;--.          \      //
//                           ,'            / ,'  `.         \     //
//                          /:            (_(   ,' \         )    //
//                         /:.               \_(  /-. .:::,;/     //
//                        (::..                 `-'\ "`""'        //
////////////////////////////////////////////////////////////////////
//                                                                //
//  Daniel Vazquez,  daniel.vazquez@upm.es                        //
//  28/03/22                                                      //
//                                                                //
//  Centro de Electronica Industrial (CEI)                        //
//  Universidad Politecnica de Madrid (UPM)                       //
//                                                                //
////////////////////////////////////////////////////////////////////

package overlay

import chisel3._
import chisel3.util._
import freechips.rocketchip.config._
import freechips.rocketchip.tile._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tilelink._

case class OverlayParams(
    cellConfigBits: Int,
    inputNodes:     Int,
    outputNodes:    Int,
    fifoDepth:      Int,
    blackBox:       Boolean)

case object OverlayKey extends Field[OverlayParams]

abstract trait UsesOverlayOnlyParameters {
    implicit val p: Parameters

    val params = p(OverlayKey)
    val cellConfigBits = params.cellConfigBits
    val inputNodes = params.inputNodes
    val outputNodes = params.outputNodes
    val fifoDepth = params.fifoDepth
    val blackBox = params.blackBox
}

class Overlay(opcodes: OpcodeSet)(implicit p: Parameters) extends LazyRoCC(opcodes) 
    with UsesOverlayOnlyParameters {

    override lazy val module = new OverlayModuleImp(this)

    val configNode = LazyModule(new ConfigNode())
    val inputNode = Seq.fill(inputNodes) {LazyModule(new InputNode())}
    val outputNode = Seq.fill(outputNodes) {LazyModule(new OutputNode())}

    atlNode := configNode.masterNode
    inputNode.map(_.masterNode).foreach { atlNode := _ }
    outputNode.map(_.masterNode).foreach { atlNode := _ }

}

class OverlayModuleImp(outer: Overlay)(implicit p: Parameters) extends LazyRoCCModuleImp(outer)
    with HasCoreParameters 
    with HasL1CacheParameters 
    with UsesOverlayOnlyParameters {

    val cacheParams = tileParams.icache.get

    val core = if(blackBox) Module(new OverlayBlackBox(
            fixedPoint = false,
            fractionLength = 0,
            dataWidth = xLen,
            inputNodes = inputNodes,
            outputNodes = outputNodes,
            fifoDepth = fifoDepth,
            cellConfigBits = cellConfigBits))
        else Module(new DummyOverlay(
            dataWidth = xLen,
            inputNodes = inputNodes,
            outputNodes = outputNodes,
            cellConfigBits = cellConfigBits))

    val rocc = Module(new ControlUnit)
    val configNode = outer.configNode.module
    val inputNode = outer.inputNode.map(_.module)
    val outputNode = outer.outputNode.map(_.module)

    val data_in = Wire(Vec(inputNodes, UInt(xLen.W)))
    val data_in_valid = Wire(Vec(inputNodes, Bool()))
    val data_in_ready = Wire(Vec(inputNodes, Bool()))
    val data_out = Wire(Vec(outputNodes, UInt(xLen.W)))
    val data_out_valid = Wire(Vec(outputNodes, Bool()))
    val data_out_ready = Wire(Vec(outputNodes, Bool()))

    // RoCC Interface
    rocc.io.rocc.cmd <> io.cmd
    io.busy <> rocc.io.rocc.busy
    io.interrupt <> rocc.io.rocc.interrupt
    rocc.io.rocc.exception <> io.exception
    io.mem.req.valid := false.B

    // Config Node
    configNode.io.control <> rocc.io.bsAddr
    configNode.io.clear := rocc.io.bs_clear
    rocc.io.bs_done := configNode.io.done

    // IO Nodes
    (inputNode zipWithIndex) map {case (node, i) =>
        node.io.control <> rocc.io.inAddr(i)
        node.io.clear := rocc.io.clear
        data_in(i) := node.io.node.bits.data
        data_in_valid(i) := node.io.node.valid && rocc.io.start
        node.io.node.ready := data_in_ready(i) && rocc.io.start
    }

    (outputNode zipWithIndex) map {case (node, i) =>
        node.io.control <> rocc.io.outAddr(i)
        node.io.clear := rocc.io.clear
        rocc.io.done(i) := node.io.done
        node.io.node.bits.data := data_out(i)
        node.io.node.valid := data_out_valid(i)
        data_out_ready(i) := node.io.node.ready
    }

    // Core IO
    core.io.clock := clock
    core.io.reset := reset.asBool //|| rocc.io.clear

    core.io.cell_config := configNode.io.cell_config

    core.io.data_in := Cat(data_in.reverse)
    core.io.data_in_valid := Cat(data_in_valid.reverse)
    data_in_ready := core.io.data_in_ready.asBools

    (data_out zipWithIndex).map { case (node, i) =>
        node := core.io.data_out(xLen*(i+1) - 1, xLen*i)
    }
    data_out_valid := core.io.data_out_valid.asBools
    core.io.data_out_ready := Cat(data_out_ready.reverse)

}

case class DPROverlayParams(
    inputNodes:     Int,
    outputNodes:    Int,
    blackBox:       Boolean)

case object DPROverlayKey extends Field[DPROverlayParams]

abstract trait UsesDPROverlayOnlyParameters {
    implicit val p: Parameters

    val params = p(DPROverlayKey)
    val inputNodes = params.inputNodes
    val outputNodes = params.outputNodes
    val blackBox = params.blackBox
}

class DPROverlay(opcodes: OpcodeSet)(implicit p: Parameters) extends LazyRoCC(opcodes) 
    with UsesDPROverlayOnlyParameters {

    override lazy val module = new DPROverlayModuleImp(this)

    val configNode = LazyModule(new DPRConfigNode())
    val inputNode = Seq.fill(inputNodes) {LazyModule(new DPRInputNode())}
    val outputNode = Seq.fill(outputNodes) {LazyModule(new DPROutputNode())}

    atlNode := configNode.masterNode
    inputNode.map(_.masterNode).foreach { atlNode := _ }
    outputNode.map(_.masterNode).foreach { atlNode := _ }

}

class DPROverlayModuleImp(outer: DPROverlay)(implicit p: Parameters) extends LazyRoCCModuleImp(outer)
    with HasCoreParameters 
    with HasL1CacheParameters 
    with UsesDPROverlayOnlyParameters {

    val cacheParams = tileParams.icache.get

    val core = if(blackBox) Module(new DPROverlayBlackBox(
            dataWidth = xLen,
            inputNodes = inputNodes,
            outputNodes = outputNodes))
        else Module(new DPRDummyOverlay(
            dataWidth = xLen,
            inputNodes = inputNodes,
            outputNodes = outputNodes))

    val rocc = Module(new DPRControlUnit)
    val configNode = outer.configNode.module
    val inputNode = outer.inputNode.map(_.module)
    val outputNode = outer.outputNode.map(_.module)

    val data_in = Wire(Vec(inputNodes, UInt(xLen.W)))
    val data_in_valid = Wire(Vec(inputNodes, Bool()))
    val data_in_ready = Wire(Vec(inputNodes, Bool()))
    val data_out = Wire(Vec(outputNodes, UInt(xLen.W)))
    val data_out_valid = Wire(Vec(outputNodes, Bool()))
    val data_out_ready = Wire(Vec(outputNodes, Bool()))

    // RoCC Interface
    rocc.io.rocc.cmd <> io.cmd
    io.busy <> rocc.io.rocc.busy
    io.interrupt <> rocc.io.rocc.interrupt
    rocc.io.rocc.exception <> io.exception
    io.mem.req.valid := false.B

    // Config Node
    configNode.io.control <> rocc.io.bsAddr
    configNode.io.clear := false.B //rocc.io.clear
    rocc.io.bs_done := configNode.io.done

    // IO Nodes
    (inputNode zipWithIndex) map {case (node, i) =>
        node.io.control <> rocc.io.inAddr(i)
        node.io.clear := rocc.io.clear
        data_in(i) := node.io.node.bits.data
        data_in_valid(i) := node.io.node.valid && rocc.io.start
        node.io.node.ready := data_in_ready(i) && rocc.io.start
    }

    (outputNode zipWithIndex) map {case (node, i) =>
        node.io.control <> rocc.io.outAddr(i)
        node.io.clear := rocc.io.clear
        rocc.io.done(i) := node.io.done
        node.io.node.bits.data := data_out(i)
        node.io.node.valid := data_out_valid(i)
        data_out_ready(i) := node.io.node.ready
    }

    // Core IO
    core.io.clock := clock
    core.io.reset := reset.asBool //|| rocc.io.clear

    //core.io.cell_config := configNode.io.cell_config

    core.io.data_in := Cat(data_in.reverse)
    core.io.data_in_valid := Cat(data_in_valid.reverse)
    data_in_ready := core.io.data_in_ready.asBools

    (data_out zipWithIndex).map { case (node, i) =>
        node := core.io.data_out(xLen*(i+1) - 1, xLen*i)
    }
    data_out_valid := core.io.data_out_valid.asBools
    core.io.data_out_ready := Cat(data_out_ready.reverse)

}

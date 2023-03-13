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
//  03/28/22                                                      //
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

class ControlIO(val w : Int) extends Bundle {
    val addr = Output(UInt(w.W))
}

class FullControlIO(override val w : Int) extends ControlIO(w){
    val info = Output(UInt(w.W))
}

class ControlUnit(implicit val p: Parameters) extends Module 
    with HasCoreParameters
    with UsesOverlayOnlyParameters{

    val io = IO(new Bundle {
        val rocc = new Bundle {
            val cmd = Flipped(Decoupled(new RoCCCommand))
            //val resp = Decoupled(new RoCCResponse)
            val busy = Output(Bool())
            val interrupt = Output(Bool())
            val exception = Input(Bool())
        }
        val bsAddr = Valid(new ControlIO(xLen))
        val inAddr = Vec(inputNodes, Valid(new FullControlIO(xLen)))
        val outAddr = Vec(outputNodes, Valid(new FullControlIO(xLen)))
        val bs_done = Input(Bool())
        val done = Vec(outputNodes, Input(Bool()))
        val clear = Output(Bool())
        val bs_clear = Output(Bool())
        val start = Output(Bool())
    })

    val s_idle :: s_addrLoad :: s_exe :: s_done :: Nil = Enum(4)
    val state = RegInit(s_idle)

    val busy = io.rocc.busy
    val cmd = Queue(io.rocc.cmd)
    val funct = cmd.bits.inst.funct
    val addr = cmd.bits.rs1
    val info = cmd.bits.rs2
    val start = funct === 0.U
    val clear = funct === 1.U
    val clear_reg = Reg(Bool())
    val bitstreamLoad = funct === 7.U
    val addr_load = (funct > 7.U & funct < 24.U)
    val doneMask = RegInit(VecInit(Seq.fill(outputNodes)(false.B)))  //(outputNodes, Bool()))
    val done = (io.done, doneMask).zipped.map(_ || ~_)

    when(state === s_idle){

        when(cmd.fire() && (bitstreamLoad || addr_load)){
            state := s_addrLoad
        }

    }.elsewhen(state === s_addrLoad){

        when(cmd.fire() && start){
            state := s_exe
        }

    }.elsewhen(state === s_exe){
        when(done.reduce(_ && _)){
            state := s_done
        }

    }.elsewhen(state === s_done) { 
        state := s_idle
        doneMask.map(_ := false.B)
    }

    when(cmd.fire() && clear){
        state := s_idle
    }

    busy := state =/= s_idle
    io.rocc.interrupt := false.B

    io.bsAddr.bits.addr := addr
    io.bsAddr.valid := cmd.fire() && bitstreamLoad

    (io.inAddr zipWithIndex) map { case (node, i) =>
        node.bits.addr := addr
        node.bits.info := info
        node.valid := cmd.fire() && funct === 8.U + i.U
    }

    (io.outAddr zipWithIndex) map { case (node, i) =>
        node.bits.addr := addr
        node.bits.info := info
        when(cmd.fire() && funct === 16.U + i.U){
            node.valid := true.B
            doneMask(i) := true.B
        }.otherwise{
            node.valid := false.B
        }
    }

    clear_reg := clear && cmd.fire()
    io.clear := state === s_done //clear_reg || state === s_done
    io.bs_clear := clear_reg
    io.start := state === s_exe && io.bs_done
    cmd.ready := state === s_idle || state === s_addrLoad
}

class DPRControlUnit(implicit val p: Parameters) extends Module 
    with HasCoreParameters
    with UsesDPROverlayOnlyParameters{

    val io = IO(new Bundle {
        val rocc = new Bundle {
            val cmd = Flipped(Decoupled(new RoCCCommand))
            //val resp = Decoupled(new RoCCResponse)
            val busy = Output(Bool())
            val interrupt = Output(Bool())
            val exception = Input(Bool())
        }
        val bsAddr = Valid(new ControlIO(xLen))
        val inAddr = Vec(inputNodes, Valid(new FullControlIO(xLen)))
        val outAddr = Vec(outputNodes, Valid(new FullControlIO(xLen)))
        val bs_done = Input(Bool())
        val done = Vec(outputNodes, Input(Bool()))
        val clear = Output(Bool())
        val start = Output(Bool())
    })

    val s_idle :: s_addrLoad :: s_exe :: s_done :: Nil = Enum(4)
    val state = RegInit(s_idle)

    val busy = io.rocc.busy
    val cmd = Queue(io.rocc.cmd)
    val funct = cmd.bits.inst.funct
    val addr = cmd.bits.rs1
    val info = cmd.bits.rs2
    val start = funct === 0.U
    val clear = funct === 1.U
    val clear_reg = Reg(Bool())
    val bitstreamLoad = funct === 7.U
    val addr_load = (funct > 7.U & funct < 24.U)
    val doneMask = RegInit(VecInit(Seq.fill(outputNodes)(false.B)))  //(outputNodes, Bool()))
    val done = (io.done, doneMask).zipped.map(_ || ~_)

    when(state === s_idle){

        when(cmd.fire() && (bitstreamLoad || addr_load)){
            state := s_addrLoad
        }

    }.elsewhen(state === s_addrLoad){

        when(cmd.fire() && start){
            state := s_exe
        }

    }.elsewhen(state === s_exe){
        when(done.reduce(_ && _)){
            state := s_done
        }

    }.elsewhen(state === s_done) { 
        state := s_idle
        doneMask.map(_ := false.B)
    }

    when(cmd.fire() && clear){
        state := s_idle
    }

    busy := state =/= s_idle
    io.rocc.interrupt := false.B

    io.bsAddr.bits.addr := addr
    io.bsAddr.valid := cmd.fire() && bitstreamLoad

    (io.inAddr zipWithIndex) map { case (node, i) =>
        node.bits.addr := addr
        node.bits.info := info
        node.valid := cmd.fire() && funct === 8.U + i.U
    }

    (io.outAddr zipWithIndex) map { case (node, i) =>
        node.bits.addr := addr
        node.bits.info := info
        when(cmd.fire() && funct === 16.U + i.U){
            node.valid := true.B
            doneMask(i) := true.B
        }.otherwise{
            node.valid := false.B
        }
    }

    clear_reg := clear && cmd.fire()
    io.clear := clear_reg || state === s_done
    io.start := state === s_exe && io.bs_done
    cmd.ready := state === s_idle || state === s_addrLoad
}
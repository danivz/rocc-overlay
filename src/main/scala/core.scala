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
import chisel3.experimental.{IntParam, BaseModule}
import freechips.rocketchip.config._
import freechips.rocketchip.tile._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tilelink._

class OverlayIO(
    val dataWidth       : Int,
    val inputNodes      : Int,
    val outputNodes     : Int,
    val cellConfigBits  : Int
    ) 
    extends Bundle{

    val clock           = Input(Clock())
    val reset           = Input(Bool())
    val cell_config     = Input(UInt(cellConfigBits.W))
    val data_in         = Input(UInt((dataWidth*inputNodes).W))
    val data_in_valid   = Input(UInt(inputNodes.W))
    val data_in_ready   = Output(UInt(inputNodes.W))
    val data_out        = Output(UInt((dataWidth*outputNodes).W))
    val data_out_valid  = Output(UInt(outputNodes.W))
    val data_out_ready  = Input(UInt(outputNodes.W))
}

class DPROverlayIO(
    val dataWidth       : Int,
    val inputNodes      : Int,
    val outputNodes     : Int
    ) 
    extends Bundle{

    val clock           = Input(Clock())
    val reset           = Input(Bool())
    val data_in         = Input(UInt((dataWidth*inputNodes).W))
    val data_in_valid   = Input(UInt(inputNodes.W))
    val data_in_ready   = Output(UInt(inputNodes.W))
    val data_out        = Output(UInt((dataWidth*outputNodes).W))
    val data_out_valid  = Output(UInt(outputNodes.W))
    val data_out_ready  = Input(UInt(outputNodes.W))
}

trait HasOverlayIO extends BaseModule {

    val dataWidth       : Int
    val inputNodes      : Int
    val outputNodes     : Int
    val cellConfigBits  : Int

    val io = IO(new OverlayIO(dataWidth, inputNodes, outputNodes, cellConfigBits))
}

trait HasDPROverlayIO extends BaseModule {
    val dataWidth       : Int
    val inputNodes      : Int
    val outputNodes     : Int

    val io = IO(new DPROverlayIO(dataWidth, inputNodes, outputNodes))
}

class OverlayBlackBox(
    val fixedPoint      : Boolean,
    val fractionLength  : Int,
    val dataWidth       : Int,
    val inputNodes      : Int,
    val outputNodes     : Int,
    val fifoDepth       : Int,
    val cellConfigBits  : Int
    ) 
    extends BlackBox(
    Map(
        "C_FIXED_POINT"     -> IntParam(if(fixedPoint) 1 else 0),
        "C_FRACTION_LENGTH" -> IntParam(fractionLength),
        "C_DATA_WIDTH"      -> IntParam(dataWidth),
        "C_INPUT_NODES"     -> IntParam(inputNodes),
        "C_OUTPUT_NODES"    -> IntParam(outputNodes),
        "C_FIFO_DEPTH"      -> IntParam(fifoDepth))
    ) 
    with HasBlackBoxResource
    with HasOverlayIO
{
    addResource("/vsrc/OverlayBlackBox.v")

}

class DPROverlayBlackBox(
    val dataWidth       : Int,
    val inputNodes      : Int,
    val outputNodes     : Int
    ) 
    extends BlackBox(
    Map(
        "C_DATA_WIDTH"      -> IntParam(dataWidth),
        "C_INPUT_NODES"     -> IntParam(inputNodes),
        "C_OUTPUT_NODES"    -> IntParam(outputNodes))
    ) 
    with HasBlackBoxResource
    with HasDPROverlayIO
{
    addResource("/vsrc/DPROverlayBlackBox.v")

}

class DummyOverlay(
    val dataWidth       : Int,
    val inputNodes      : Int,
    val outputNodes     : Int,
    val cellConfigBits  : Int
    ) 
    extends Module
    with HasOverlayIO
{

    val cell_config_reg = Reg(UInt(cellConfigBits.W))

    io.data_out := io.data_in
    io.data_out_valid := io.data_in_valid
    io.data_in_ready := io.data_out_ready
    cell_config_reg := io.cell_config

}

class DPRDummyOverlay(
    val dataWidth       : Int,
    val inputNodes      : Int,
    val outputNodes     : Int
    ) 
    extends Module
    with HasDPROverlayIO
{

    io.data_out := io.data_in
    io.data_out_valid := io.data_in_valid
    io.data_in_ready := io.data_out_ready

}

class TestOverlay extends Module
{

    val io = IO(new Bundle {
        val data_in         = Input(UInt(192.W))
        val data_out        = Output(UInt(192.W))
    })

    val input_vec = Wire(Vec(192, Bool()))
    val output_vec = Wire(Vec(192, Bool()))

    // Split input
    input_vec := io.data_in.asBools

    // Assign
    output_vec := input_vec

    // Join output
    io.data_out := Cat(output_vec)

}
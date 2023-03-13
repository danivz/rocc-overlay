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

class ConfigDeser(val dataWidth: Int, val cellBits :Int, val inputNodes: Int, val outputNodes: Int) extends Module {

    val io = IO( new Bundle{
        val serial_input = Flipped(Decoupled(new DataIO(dataWidth)))
        val parallel_output = Output(UInt(cellBits.W))
        val clear = Input(Bool())
        val done = Output(Bool())
        val size = Valid(new DataIO(dataWidth))
    })

    val max_words : Int = inputNodes * outputNodes * cellBits / 32
    val word_counter = RegInit(0.U(log2Up(max_words).W))
    val word_counter_next = word_counter + (dataWidth/32).U
    val cell_count = Reg(UInt(16.W))
    val cell_config = Reg(Vec(cellBits/dataWidth, UInt(dataWidth.W)))
    val size_trigger_reg = RegInit(false.B)
    val done = Reg(Bool())

    val s_idle :: s_loadword :: s_update :: s_done :: Nil = Enum(4)
    val state = RegInit(s_idle)

    when (state === s_idle) {

        when (io.serial_input.fire()) {
            when (word_counter_next > 1.U) { cell_count := io.serial_input.bits.data(15, 0) }
            when(word_counter_next === 2.U) { state := s_loadword }
            word_counter := word_counter_next
            done := false.B
        }

    }.elsewhen (state === s_loadword) {

        when (io.serial_input.fire()) {

            word_counter := word_counter_next

            cell_config.zipWithIndex.map { case (reg, i) => 
                if (i == 0) {
                    reg := io.serial_input.bits.data
                } else {
                    reg := cell_config(i - 1)
                }
            }

            when ((word_counter_next - 2.U) % (cellBits/dataWidth).U === 0.U) {
                state := s_update
            }
        }

    }.elsewhen (state === s_update) {

        when ((word_counter - 2.U) / 6.U === cell_count) {
            state := s_done
        }.otherwise {
            state := s_loadword
        }

    }.elsewhen (state === s_done) { 

        done := true.B
        state := s_idle
        word_counter := 0.U
        size_trigger_reg := false.B

    }

    io.serial_input.ready := state === s_idle || state === s_loadword
    io.parallel_output := Mux(state === s_update, Cat(cell_config) | 1.U << (cellBits - 1).U, 0.U)
    io.done := done //state === s_done
    val size_trigger = state === s_idle && io.serial_input.fire() && word_counter_next > 1.U
    when (size_trigger) { size_trigger_reg := true.B }
    io.size.bits.data := cell_count * (cellBits/8).U + 8.U
    io.size.valid := size_trigger_reg

}

class ConfigNode(implicit p: Parameters) extends LazyModule with UsesOverlayOnlyParameters{
    lazy val module = new ConfigNodeModuleImp(this)
    val masterNode = TLClientNode(Seq(TLMasterPortParameters.v1(
        Seq(TLMasterParameters.v1(name = "OverlayConfigMemPort", sourceId = IdRange(0,1))))))
}

class ConfigNodeModuleImp(outer: ConfigNode)(implicit p: Parameters) extends LazyModuleImp(outer) 
    with HasCoreParameters
    with HasL1CacheParameters
    with UsesOverlayOnlyParameters{

    val cacheParams = tileParams.icache.get
    
    val io = IO(new Bundle {
        val clear = Input(Bool())
        val control = Flipped(Valid(new ControlIO(xLen)))
        val done = Output(Bool())
        val cell_config = Output(UInt(cellConfigBits.W))
    })

    val block_buffer = Module(new FifoMem(
        dataWidth = xLen, 
        size = 2*cacheBlockBytes*8/xLen, 
        threshold = cacheBlockBytes*8/xLen))

    val deserializer = Module(new ConfigDeser(
        dataWidth = xLen, 
        cellBits = cellConfigBits, 
        inputNodes = inputNodes, 
        outputNodes = outputNodes))

    val (tl_out, edge) = outer.masterNode.out.head
    private val acquire = tl_out.a 
    private val grant = tl_out.d

    val s_idle :: s_memreq :: s_store :: s_wait :: s_done :: Nil = Enum(5)
    val state = RegInit(s_idle)

    val data_addr = Reg(UInt(xLen.W))
    val data_size = RegInit(64.U(xLen.W))
    val block_addr = Cat(data_addr(xLen - 1, lgCacheBlockBytes), 0.U(lgCacheBlockBytes.W))
    val next_addr = block_addr + cacheBlockBytes.U
    val data_offset = data_addr(lgCacheBlockBytes - 1, 0)
    val data_offset_reg = Reg(UInt(xLen.W))
    val wait_size = RegInit(true.B)
    
    val byte_counter = Reg(UInt(xLen.W))
    val byte_counter_next = byte_counter + (xLen.asUInt/8.U)

    when (deserializer.io.size.fire()) {
        data_size := deserializer.io.size.bits.data + data_offset_reg
        wait_size := false.B
    }

    when(state === s_idle) {

        when(io.control.fire()){
            state := s_memreq
            data_addr := io.control.bits.addr
            data_offset_reg := io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            byte_counter := 0.U
        }

    }.elsewhen(state === s_memreq) {

        when(acquire.ready){
            state := s_store
        }

    }.elsewhen(state === s_store){

        when(grant.fire()){

            when(byte_counter_next % cacheBlockBytes.U === 0.U){

                when (wait_size) {

                    data_addr := next_addr
                    state := s_wait

                }.elsewhen(byte_counter_next < data_size){

                    data_addr := next_addr

                    when(~block_buffer.io.full_block){ 
                        state := s_memreq 
                    }.otherwise{ 
                        state := s_wait
                    }
                    
                }.otherwise{
                    state := s_done
                }
            }

            byte_counter := byte_counter_next
            
        }

    }.elsewhen(state === s_wait){
        when(~block_buffer.io.full_block && ~wait_size){
            state := s_memreq
        }
    }

    when(io.clear){
        state := s_idle
        wait_size := true.B
        data_size := 64.U
    }

    // Request signals
    acquire.valid := (state === s_memreq)
    acquire.bits := edge.Get(
        fromSource = 0.U,
        toAddress = block_addr,
        lgSize = lgCacheBlockBytes.U)._2

    // Receive signals
    grant.ready := ~block_buffer.io.full_block && state === s_store
    block_buffer.io.din := grant.bits.data
    block_buffer.io.write := grant.fire() && byte_counter >= data_offset && byte_counter < data_size
    block_buffer.io.clear := io.clear

    // Node signals
    deserializer.io.serial_input.bits.data := block_buffer.io.dout
    deserializer.io.serial_input.valid := ~block_buffer.io.empty
    block_buffer.io.read := deserializer.io.serial_input.fire()
    deserializer.io.clear := io.clear
    io.done := deserializer.io.done
    io.cell_config := deserializer.io.parallel_output

    // Tie off unused channels
    tl_out.b.ready := true.B
    tl_out.c.valid := false.B
    tl_out.e.valid := false.B 
}

class DPRConfigNode(implicit p: Parameters) extends LazyModule with UsesDPROverlayOnlyParameters{
    lazy val module = new DPRConfigNodeModuleImp(this)
    val masterNode = TLClientNode(Seq(TLMasterPortParameters.v1(
        Seq(TLMasterParameters.v1(name = "OverlayConfigMemPort", sourceId = IdRange(0,1))))))
}

class DPRConfigNodeModuleImp(outer: DPRConfigNode)(implicit p: Parameters) extends LazyModuleImp(outer) 
    with HasCoreParameters
    with HasL1CacheParameters
    with UsesDPROverlayOnlyParameters{

    val cacheParams = tileParams.icache.get
    
    val io = IO(new Bundle {
        val clear = Input(Bool())
        val control = Flipped(Valid(new ControlIO(xLen)))
        val done = Output(Bool())
    })

    val done = Reg(Bool())

    when(io.control.fire()){
        done := true.B
    }.elsewhen(io.clear) {
        done := false.B
    }

    io.done := done

    val (tl_out, edge) = outer.masterNode.out.head
    private val acquire = tl_out.a 
    private val grant = tl_out.d

    acquire.valid := false.B
    grant.ready := true.B

    // Tie off unused channels
    tl_out.b.ready := true.B
    tl_out.c.valid := false.B
    tl_out.e.valid := false.B 
}
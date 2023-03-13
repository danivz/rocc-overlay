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
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tile._
import freechips.rocketchip.tilelink._

class DataIO(val w: Int) extends Bundle {
    val data = Output(UInt(w.W))
}

class FifoMem(val dataWidth: Int, val size: Int, val threshold: Int) extends Module {

    val io = IO(new Bundle {
        val clear       = Input(Bool())
        val write       = Input(Bool())
        val full        = Output(Bool())
        val full_block  = Output(Bool())
        val din         = Input(UInt(dataWidth.W))
        val read        = Input(Bool())
        val empty       = Output(Bool())
        val empty_block = Output(Bool())
        val dout        = Output(UInt(dataWidth.W))
    })

    val s_empty :: s_accept :: s_full :: Nil = Enum(3)
    val state = RegInit(s_empty)

    val write_pointer = RegInit(0.U(log2Ceil(size).W))
    val read_pointer = RegInit(0.U(log2Ceil(size).W))
    val data_count = RegInit(0.U(log2Ceil(size).W))
    val data = Mem(size, UInt(dataWidth.W))

    io.dout := 0.U

    when (io.clear) {
        state := s_empty
        write_pointer := 0.U
        read_pointer := 0.U
        data_count := 0.U
    }

    when(state === s_empty) {

        when(io.write) {
            data.write(write_pointer, io.din)
            data_count := data_count + 1.U

            when(write_pointer + 1.U < size.U){
                write_pointer := write_pointer + 1.U
            }.otherwise{
                write_pointer := 0.U
            }

            state := s_accept
        }

    }.elsewhen(state === s_accept) {

        when(io.write) {
            data.write(write_pointer, io.din)

            when(~io.read){
                data_count := data_count + 1.U
            }

            when(write_pointer + 1.U < size.U){

                write_pointer := write_pointer + 1.U

                when(write_pointer + 1.U === read_pointer && ~io.read) {
                    state := s_full
                }   

            }.otherwise{

                write_pointer := 0.U

                when(read_pointer === 0.U && ~io.read){
                    state := s_full
                }

            }

        }

        when(io.read) {
            io.dout := data.read(read_pointer)

            when(~io.write){
                data_count := data_count - 1.U
            }

            when(read_pointer + 1.U < size.U){

                read_pointer := read_pointer + 1.U

                when(read_pointer + 1.U === write_pointer && ~io.write) {
                    state := s_empty
                }

            }.otherwise{

                read_pointer := 0.U

                when(write_pointer === 0.U && ~io.write){
                    state := s_empty
                }
            }
                        
        }

    }.elsewhen(state === s_full) {
        when(io.read) {
            io.dout := data.read(read_pointer)
            data_count := data_count - 1.U
            
            when(read_pointer + 1.U < size.U){
                read_pointer := read_pointer + 1.U
            }.otherwise{
                read_pointer := 0.U
            }

            state := s_accept       
        }
    }

    io.full := state === s_full
    io.empty := state === s_empty
    io.full_block := data_count > (size - threshold).U || state === s_full
    io.empty_block := data_count < threshold.U && state =/= s_full
    
}

class FifoMemRV(val dataWidth: Int, val size: Int, val threshold: Int) extends Module {

    val io = IO(new Bundle {
        val clear       = Input(Bool())
        val din         = Flipped(Decoupled(UInt(dataWidth.W)))
        val dout        = Decoupled(UInt(dataWidth.W))
        val full        = Output(Bool())
        val full_block  = Output(Bool())
        val empty       = Output(Bool())
        val empty_block = Output(Bool())
    })

    val memory = Mem(size, UInt(dataWidth.W))
    val write_pointer = RegInit(0.U(log2Ceil(size).W))
    val read_pointer = RegInit(0.U(log2Ceil(size).W))
    val data_count = RegInit(0.U((log2Ceil(size) + 1).W))
    val rd_en, wr_en = Wire(Bool())
    val empty = Wire(Bool())
    val empty_block = Wire(Bool())
    val full = Wire(Bool())
    val full_block = Wire(Bool())
    val dout = RegInit(0.U(dataWidth.W))
    val dout_v = RegInit(false.B)

    dout := dout

    when (io.dout.ready) {
        dout_v := false.B
    }

    // Write process
    when (wr_en) {

        memory.write(write_pointer, io.din.bits)
        when (~rd_en) { data_count := data_count + 1.U }

        when (write_pointer + 1.U === size.U) {
            write_pointer := 0.U
        }.otherwise {
            write_pointer := write_pointer + 1.U
        }
    }

    // Read process
    when (rd_en) {

        dout := memory.read(read_pointer)
        dout_v := true.B
        when (~wr_en) { data_count := data_count - 1.U }

        when (read_pointer + 1.U === size.U) {
            read_pointer := 0.U
        }.otherwise {
            read_pointer := read_pointer + 1.U
        }
    }

    // Control process
    when (data_count === size.U) {
        full := true.B
    }.otherwise {
        full := false.B
    }
    when (data_count > (size - threshold).U) {
        full_block := true.B
    }.otherwise {
        full_block := false.B
    }
    when (data_count === 0.U) {
        empty := true.B
    }.otherwise {
        empty := false.B
    }
    when (data_count < threshold.U) {
        empty_block := true.B
    }.otherwise {
        empty_block := false.B
    }

    // Synchronous reset
    when (io.clear) {
        write_pointer := 0.U
        read_pointer := 0.U
        data_count := 0.U
        dout := 0.U
        dout_v := false.B
    }

    wr_en := io.din.valid && ~full 
    rd_en := io.dout.ready && ~empty 
    io.din.ready := ~full
    io.dout.bits := dout
    io.dout.valid := dout_v
    io.full := full
    io.full_block := full_block
    io.empty := empty
    io.empty_block := empty_block

}

class ModDiv extends Module{
    val io = IO(new Bundle{
        val byte_counter = Input(UInt(64.W))
        val data_offset = Input(UInt(64.W))
        val data_stride = Input(UInt(64.W))
        val din_v = Output(Bool())
    })

    io.din_v := (io.byte_counter - io.data_offset) % (io.data_stride * 8.U) === 0.U
}

class InputNode(implicit p: Parameters) extends LazyModule with UsesOverlayOnlyParameters{
    lazy val module = new InputNodeModuleImp(this)
    val masterNode = TLClientNode(Seq(TLMasterPortParameters.v1(
        Seq(TLMasterParameters.v1(name = "OverlayInputMemPort", sourceId = IdRange(0, inputNodes))))))
}

class InputNodeModuleImp(outer: InputNode)(implicit p: Parameters) extends LazyModuleImp(outer) 
    with HasCoreParameters
    with HasL1CacheParameters
    with UsesOverlayOnlyParameters{

    val cacheParams = tileParams.icache.get

    val io = IO(new Bundle {
        val clear = Input(Bool())
        val control = Flipped(Valid(new FullControlIO(xLen)))
        val node = Decoupled(new DataIO(xLen))
    })

    val block_buffer = Module(new FifoMemRV(
        dataWidth = xLen, 
        size = 32*cacheBlockBytes/xLen, 
        threshold = 8*cacheBlockBytes/xLen))

    val (tl_out, edge) = outer.masterNode.out.head
    private val acquire = tl_out.a 
    private val grant = tl_out.d

    val s_idle :: s_memreq :: s_store :: s_wait :: s_done :: Nil = Enum(5)
    val state = RegInit(s_idle)

    val s_stride_idle :: s_stride_cero :: s_stride_cero_load :: s_stride_load :: Nil = Enum(4)
    val state_stride = RegInit(s_stride_idle)

    val data_addr = RegInit(0.U(xLen.W))
    val block_addr = Cat(data_addr(xLen - 1, lgCacheBlockBytes), 0.U(lgCacheBlockBytes.W))
    val next_addr = block_addr + cacheBlockBytes.U
    val data_offset = data_addr(lgCacheBlockBytes - 1, 0)
    val data_size = RegInit(0.U((xLen/2).W))
    val data_stride = RegInit(0.U((xLen/2).W))
    val data_reg = RegInit(0.U(xLen.W))
    val byte_counter = RegInit(0.U((xLen/2).W))
    val byte_counter_next = byte_counter + (xLen/8).U

    val stride_counter = RegInit(0.U((xLen/2).W))
    val next_stride_count = stride_counter + (xLen.asUInt/8.U)
    val stride_offset = RegInit(0.U((xLen/2).W))
    val last_stride_addr = RegInit(0.U(xLen.W))
    val din_v = Wire(Bool())
    val stride_bytes = data_stride * (xLen/8).U
    val transaction_counter = RegInit(0.U((log2Up(8*cacheBlockBytes/xLen)).W))

    // Memory FSM
    when(state === s_idle) {

        when(io.control.fire()){
            state := s_memreq
            data_addr := io.control.bits.addr
            data_size := io.control.bits.info((xLen/2)-1, 0) + 
                io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            data_stride := io.control.bits.info(xLen-1, (xLen/2))
            stride_counter := io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            stride_offset := io.control.bits.addr(lgCacheBlockBytes - 1, 0)
        }

    }.elsewhen(state === s_memreq) {

        when(acquire.ready){
            state := s_store
        }

    }.elsewhen(state === s_store){

        when(grant.fire()){

            byte_counter := byte_counter_next
            transaction_counter := transaction_counter + 1.U

            when(byte_counter_next % cacheBlockBytes.U === 0.U){

                when(byte_counter_next < data_size && data_stride === 1.U){

                    data_addr := next_addr

                    when(~block_buffer.io.full_block){ 
                        state := s_memreq 
                    }.otherwise{ 
                        state := s_wait
                    }  

                }.elsewhen(stride_counter < data_size && data_stride > 1.U){

                    when (din_v) {
                        // Last data is valid
                        data_addr := block_addr + cacheBlockBytes.U - (xLen/8).U + stride_bytes
                    }.otherwise {
                        // Last data is not valid
                        data_addr := last_stride_addr + stride_bytes
                    }

                    when(~block_buffer.io.full_block){ 
                        state := s_memreq 
                    }.otherwise{ 
                        state := s_wait
                    }

                }.otherwise{
                    state := s_done
                }
            }

            when (din_v && data_stride > 1.U) {

                stride_counter := next_stride_count
                last_stride_addr := block_addr + transaction_counter * (xLen/8).U

                when (stride_bytes < ((2*cacheBlockBytes).U - (transaction_counter * (xLen/8).U))) {

                    stride_offset := byte_counter + stride_bytes

                }.otherwise {

                    when (stride_bytes % cacheBlockBytes.U === 0.U) {

                        stride_offset := byte_counter + cacheBlockBytes.U

                    }.elsewhen (stride_bytes < cacheBlockBytes.U * 2.U) {

                        stride_offset := byte_counter + stride_bytes - 
                            (stride_bytes/cacheBlockBytes.U) * cacheBlockBytes.U

                    }.otherwise {

                        stride_offset := byte_counter + stride_bytes - 
                            ((stride_bytes/cacheBlockBytes.U) - 1.U) * cacheBlockBytes.U
                    }
                }

            }
        }

    }.elsewhen(state === s_wait){

        when(~block_buffer.io.full_block){
            state := s_memreq
        }

    }

    // Request signals
    acquire.valid := (state === s_memreq)
    acquire.bits := edge.Get(
        fromSource = 0.U,
        toAddress = block_addr,
        lgSize = lgCacheBlockBytes.U)._2

    // Receive signals
    grant.ready := block_buffer.io.din.ready
    block_buffer.io.din.bits := grant.bits.data

    when (data_stride <= 1.U){

        din_v := grant.valid && 
            byte_counter >= data_offset && 
            byte_counter < data_size

    }.otherwise{

        din_v := grant.valid && 
            byte_counter >= data_offset && 
            byte_counter === stride_offset && 
            stride_counter < data_size
    }

    block_buffer.io.din.valid := din_v

    // Node signal
    io.node.bits.data := 0.U

    // Node output FMS
    when (state_stride === s_stride_idle) {

        when (state =/= s_idle) {

            when (data_stride === 0.U) {
                state_stride := s_stride_cero
            }.otherwise { 
                state_stride := s_stride_load
            }
        }

    }.elsewhen (state_stride === s_stride_cero) {

        when (block_buffer.io.dout.fire()) {

            data_reg := block_buffer.io.dout.bits
            state_stride := s_stride_cero_load
        }

    }.elsewhen (state_stride === s_stride_cero_load) {

        io.node.bits.data := data_reg

    }.elsewhen (state_stride === s_stride_load) {

        io.node.bits.data := block_buffer.io.dout.bits
    }

    // Synchronous reset
    when (io.clear) {
        state := s_idle
        state_stride := s_stride_idle
        data_addr := 0.U
        data_size := 0.U
        data_stride := 0.U
        data_reg := 0.U
        byte_counter := 0.U
        stride_counter := 0.U
        stride_offset := 0.U
        last_stride_addr := 0.U
        transaction_counter := 0.U
    }

    // Node signals
    io.node.valid := state_stride === s_stride_cero_load || (state_stride === s_stride_load && block_buffer.io.dout.valid)
    block_buffer.io.dout.ready := (io.node.ready && state_stride === s_stride_load) || state_stride === s_stride_cero
    block_buffer.io.clear := io.clear

    // Tie off unused channels
    tl_out.b.ready := true.B
    tl_out.c.valid := false.B
    tl_out.e.valid := false.B
}

class OutputNode(implicit p: Parameters) extends LazyModule with UsesOverlayOnlyParameters{
    lazy val module = new OutputNodeModuleImp(this)
    val masterNode = TLClientNode(Seq(TLMasterPortParameters.v1(
        Seq(TLMasterParameters.v1(name = "OverlayOutputMemPort", sourceId = IdRange(0, outputNodes))))))
}

class OutputNodeModuleImp(outer: OutputNode)(implicit p: Parameters) extends LazyModuleImp(outer) 
    with HasCoreParameters
    with HasL1CacheParameters
    with UsesOverlayOnlyParameters{

    val cacheParams = tileParams.icache.get

    val io = IO(new Bundle {
        val clear = Input(Bool())
        val control = Flipped(Valid(new FullControlIO(xLen)))
        val node = Flipped(Decoupled(new DataIO(xLen)))
        val done = Output(Bool())
    })

    val block_buffer = Module(new FifoMemRV(
        dataWidth = xLen, 
        size = 32*cacheBlockBytes/xLen, 
        threshold = cacheBlockBytes*8/xLen))

    val (tl_out, edge) = outer.masterNode.out.head
    private val acquire = tl_out.a 
    private val grant = tl_out.d

    val s_idle :: s_wait :: s_store :: s_ack :: s_done :: Nil = Enum(5)
    val state = RegInit(s_idle)

    val data_addr = RegInit(0.U(xLen.W))
    val data_size = RegInit(0.U(xLen.W))
    val data_size_woffset = RegInit(0.U(xLen.W))
    val block_addr = Cat(data_addr(xLen - 1, lgCacheBlockBytes), 0.U(lgCacheBlockBytes.W))
    val data_offset = data_addr(lgCacheBlockBytes - 1, 0)
    val next_addr = block_addr + cacheBlockBytes.U
    val byte_counter = RegInit(0.U(xLen.W))
    val byte_counter_next = byte_counter + (xLen/8).U
    val data_counter = RegInit(0.U(xLen.W))
    val data_counter_next = data_counter + (xLen/8).U
    val byte_mask = Wire(UInt((xLen/8).W))

    when(state === s_idle) {

        when(io.control.fire()){
            data_addr := io.control.bits.addr
            data_size := io.control.bits.info
            data_size_woffset := io.control.bits.info + io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            state := s_wait
        }

    }.elsewhen(state === s_wait) {

        when((~block_buffer.io.empty_block || data_counter >= data_size) && acquire.ready) {
            state := s_store
        }

    }.elsewhen(state === s_store) {

        when(acquire.fire()){

            when(byte_counter_next % cacheBlockBytes.U === 0.U) {
                state := s_ack              
            }

            byte_counter := byte_counter_next
            
        }
    }.elsewhen(state === s_ack) {

        when(grant.fire()){
            when(byte_counter < data_size_woffset) {

                data_addr := next_addr

                when((~block_buffer.io.empty_block || data_counter >= data_size) && acquire.ready) {
                    state := s_store
                }.otherwise {
                    state := s_wait
                }

            }.otherwise {
                state := s_done
            }
        }

    }

    when (io.node.fire()) {
        data_counter := data_counter_next
    }.otherwise {
        data_counter := data_counter
    }

    // Synchronous reset
    when (io.clear) {
        state := s_idle
        data_addr := 0.U
        data_size := 0.U
        data_size_woffset := 0.U
        byte_counter := 0.U
        data_counter := 0.U
    }

    // Acquire signals
    acquire.valid := state === s_store && (block_buffer.io.dout.valid || byte_counter >= data_size_woffset || byte_counter < data_offset)
    acquire.bits := edge.Put(
                    fromSource = 0.U,
                    toAddress = block_addr, 
                    lgSize = lgCacheBlockBytes.U, 
                    data = block_buffer.io.dout.bits,
                    mask = byte_mask)._2

    // Receive signals
    grant.ready := state === s_ack

    // Node signals
    io.done := state === s_done
    val ready_tmp = state === s_store && byte_counter >= data_offset && byte_counter < data_size_woffset && acquire.ready
    block_buffer.io.dout.ready := ready_tmp

    block_buffer.io.din.bits := io.node.bits.data
    block_buffer.io.din.valid := io.node.valid
    io.node.ready := block_buffer.io.din.ready

    block_buffer.io.clear := io.clear
    byte_mask := Mux(ready_tmp, (-1.S((xLen/8).W)).asUInt, 0.U)

    // Tie off unused channels
    tl_out.b.ready := true.B
    tl_out.c.valid := false.B
    tl_out.e.valid := false.B
}


// ---------------------- DPR -------------------------- //

class DPRInputNode(implicit p: Parameters) extends LazyModule with UsesDPROverlayOnlyParameters{
    lazy val module = new DPRInputNodeModuleImp(this)
    val masterNode = TLClientNode(Seq(TLMasterPortParameters.v1(
        Seq(TLMasterParameters.v1(name = "OverlayInputMemPort", sourceId = IdRange(0, inputNodes))))))
}

class DPRInputNodeModuleImp(outer: DPRInputNode)(implicit p: Parameters) extends LazyModuleImp(outer) 
    with HasCoreParameters
    with HasL1CacheParameters
    with UsesDPROverlayOnlyParameters{

    val cacheParams = tileParams.icache.get

    val io = IO(new Bundle {
        val clear = Input(Bool())
        val control = Flipped(Valid(new FullControlIO(xLen)))
        val node = Decoupled(new DataIO(xLen))
    })

    val block_buffer = Module(new FifoMemRV(
        dataWidth = xLen, 
        size = 32*cacheBlockBytes/xLen, 
        threshold = 8*cacheBlockBytes/xLen))

    val (tl_out, edge) = outer.masterNode.out.head
    private val acquire = tl_out.a 
    private val grant = tl_out.d

    val s_idle :: s_memreq :: s_store :: s_wait :: s_done :: Nil = Enum(5)
    val state = RegInit(s_idle)

    val s_stride_idle :: s_stride_cero :: s_stride_cero_load :: s_stride_load :: Nil = Enum(4)
    val state_stride = RegInit(s_stride_idle)

    val data_addr = RegInit(0.U(xLen.W))
    val block_addr = Cat(data_addr(xLen - 1, lgCacheBlockBytes), 0.U(lgCacheBlockBytes.W))
    val next_addr = block_addr + cacheBlockBytes.U
    val data_offset = data_addr(lgCacheBlockBytes - 1, 0)
    val data_size = RegInit(0.U((xLen/2).W))
    val data_stride = RegInit(0.U((xLen/2).W))
    val data_reg = RegInit(0.U(xLen.W))
    val byte_counter = RegInit(0.U((xLen/2).W))
    val byte_counter_next = byte_counter + (xLen/8).U

    val stride_counter = RegInit(0.U((xLen/2).W))
    val next_stride_count = stride_counter + (xLen.asUInt/8.U)
    val stride_offset = RegInit(0.U((xLen/2).W))
    val last_stride_addr = RegInit(0.U(xLen.W))
    val din_v = Wire(Bool())
    val stride_bytes = data_stride * (xLen/8).U
    val transaction_counter = RegInit(0.U((log2Up(8*cacheBlockBytes/xLen)).W))

    // Memory FSM
    when(state === s_idle) {

        when(io.control.fire()){
            state := s_memreq
            data_addr := io.control.bits.addr
            data_size := io.control.bits.info((xLen/2)-1, 0) + 
                io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            data_stride := io.control.bits.info(xLen-1, (xLen/2))
            stride_counter := io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            stride_offset := io.control.bits.addr(lgCacheBlockBytes - 1, 0)
        }

    }.elsewhen(state === s_memreq) {

        when(acquire.ready){
            state := s_store
        }

    }.elsewhen(state === s_store){

        when(grant.fire()){

            byte_counter := byte_counter_next
            transaction_counter := transaction_counter + 1.U

            when(byte_counter_next % cacheBlockBytes.U === 0.U){

                when(byte_counter_next < data_size && data_stride === 1.U){

                    data_addr := next_addr

                    when(~block_buffer.io.full_block){ 
                        state := s_memreq 
                    }.otherwise{ 
                        state := s_wait
                    }  

                }.elsewhen(stride_counter < data_size && data_stride > 1.U){

                    when (din_v) {
                        // Last data is valid
                        data_addr := block_addr + cacheBlockBytes.U - (xLen/8).U + stride_bytes
                    }.otherwise {
                        // Last data is not valid
                        data_addr := last_stride_addr + stride_bytes
                    }

                    when(~block_buffer.io.full_block){ 
                        state := s_memreq 
                    }.otherwise{ 
                        state := s_wait
                    }

                }.otherwise{
                    state := s_done
                }
            }

            when (din_v && data_stride > 1.U) {

                stride_counter := next_stride_count
                last_stride_addr := block_addr + transaction_counter * (xLen/8).U

                when (stride_bytes < ((2*cacheBlockBytes).U - (transaction_counter * (xLen/8).U))) {

                    stride_offset := byte_counter + stride_bytes

                }.otherwise {

                    when (stride_bytes % cacheBlockBytes.U === 0.U) {

                        stride_offset := byte_counter + cacheBlockBytes.U

                    }.elsewhen (stride_bytes < cacheBlockBytes.U * 2.U) {

                        stride_offset := byte_counter + stride_bytes - 
                            (stride_bytes/cacheBlockBytes.U) * cacheBlockBytes.U

                    }.otherwise {

                        stride_offset := byte_counter + stride_bytes - 
                            ((stride_bytes/cacheBlockBytes.U) - 1.U) * cacheBlockBytes.U
                    }
                }

            }
        }

    }.elsewhen(state === s_wait){

        when(~block_buffer.io.full_block){
            state := s_memreq
        }

    }

    // Request signals
    acquire.valid := (state === s_memreq)
    acquire.bits := edge.Get(
        fromSource = 0.U,
        toAddress = block_addr,
        lgSize = lgCacheBlockBytes.U)._2

    // Receive signals
    grant.ready := block_buffer.io.din.ready
    block_buffer.io.din.bits := grant.bits.data

    when (data_stride <= 1.U){

        din_v := grant.valid && 
            byte_counter >= data_offset && 
            byte_counter < data_size

    }.otherwise{

        din_v := grant.valid && 
            byte_counter >= data_offset && 
            byte_counter === stride_offset && 
            stride_counter < data_size
    }

    block_buffer.io.din.valid := din_v

    // Node signal
    io.node.bits.data := 0.U

    // Node output FMS
    when (state_stride === s_stride_idle) {

        when (state =/= s_idle) {

            when (data_stride === 0.U) {
                state_stride := s_stride_cero
            }.otherwise { 
                state_stride := s_stride_load
            }
        }

    }.elsewhen (state_stride === s_stride_cero) {

        when (block_buffer.io.dout.fire()) {

            data_reg := block_buffer.io.dout.bits
            state_stride := s_stride_cero_load
        }

    }.elsewhen (state_stride === s_stride_cero_load) {

        io.node.bits.data := data_reg

    }.elsewhen (state_stride === s_stride_load) {

        io.node.bits.data := block_buffer.io.dout.bits
    }

    // Synchronous reset
    when (io.clear) {
        state := s_idle
        state_stride := s_stride_idle
        data_addr := 0.U
        data_size := 0.U
        data_stride := 0.U
        data_reg := 0.U
        byte_counter := 0.U
        stride_counter := 0.U
        stride_offset := 0.U
        last_stride_addr := 0.U
        transaction_counter := 0.U
    }

    // Node signals
    io.node.valid := state_stride === s_stride_cero_load || (state_stride === s_stride_load && block_buffer.io.dout.valid)
    block_buffer.io.dout.ready := (io.node.ready && state_stride === s_stride_load) || state_stride === s_stride_cero
    block_buffer.io.clear := io.clear

    // Tie off unused channels
    tl_out.b.ready := true.B
    tl_out.c.valid := false.B
    tl_out.e.valid := false.B
}

class DPROutputNode(implicit p: Parameters) extends LazyModule with UsesDPROverlayOnlyParameters{
    lazy val module = new DPROutputNodeModuleImp(this)
    val masterNode = TLClientNode(Seq(TLMasterPortParameters.v1(
        Seq(TLMasterParameters.v1(name = "OverlayOutputMemPort", sourceId = IdRange(0, outputNodes))))))
}

class DPROutputNodeModuleImp(outer: DPROutputNode)(implicit p: Parameters) extends LazyModuleImp(outer) 
    with HasCoreParameters
    with HasL1CacheParameters
    with UsesDPROverlayOnlyParameters{

    val cacheParams = tileParams.icache.get

    val io = IO(new Bundle {
        val clear = Input(Bool())
        val control = Flipped(Valid(new FullControlIO(xLen)))
        val node = Flipped(Decoupled(new DataIO(xLen)))
        val done = Output(Bool())
    })

    val block_buffer = Module(new FifoMemRV(
        dataWidth = xLen, 
        size = 32*cacheBlockBytes/xLen, 
        threshold = cacheBlockBytes*8/xLen))

    val (tl_out, edge) = outer.masterNode.out.head
    private val acquire = tl_out.a 
    private val grant = tl_out.d

    val s_idle :: s_wait :: s_store :: s_ack :: s_done :: Nil = Enum(5)
    val state = RegInit(s_idle)

    val data_addr = RegInit(0.U(xLen.W))
    val data_size = RegInit(0.U(xLen.W))
    val data_size_woffset = RegInit(0.U(xLen.W))
    val block_addr = Cat(data_addr(xLen - 1, lgCacheBlockBytes), 0.U(lgCacheBlockBytes.W))
    val data_offset = data_addr(lgCacheBlockBytes - 1, 0)
    val next_addr = block_addr + cacheBlockBytes.U
    val byte_counter = RegInit(0.U(xLen.W))
    val byte_counter_next = byte_counter + (xLen/8).U
    val data_counter = RegInit(0.U(xLen.W))
    val data_counter_next = data_counter + (xLen/8).U
    val byte_mask = Wire(UInt((xLen/8).W))

    when(state === s_idle) {

        when(io.control.fire()){
            data_addr := io.control.bits.addr
            data_size := io.control.bits.info
            data_size_woffset := io.control.bits.info + io.control.bits.addr(lgCacheBlockBytes - 1, 0)
            state := s_wait
        }

    }.elsewhen(state === s_wait) {

        when((~block_buffer.io.empty_block || data_counter >= data_size) && acquire.ready) {
            state := s_store
        }

    }.elsewhen(state === s_store) {

        when(acquire.fire()){

            when(byte_counter_next % cacheBlockBytes.U === 0.U) {
                state := s_ack              
            }

            byte_counter := byte_counter_next
            
        }
    }.elsewhen(state === s_ack) {

        when(grant.fire()){
            when(byte_counter < data_size_woffset) {

                data_addr := next_addr

                when((~block_buffer.io.empty_block || data_counter >= data_size) && acquire.ready) {
                    state := s_store
                }.otherwise {
                    state := s_wait
                }

            }.otherwise {
                state := s_done
            }
        }

    }

    when (io.node.fire()) {
        data_counter := data_counter_next
    }.otherwise {
        data_counter := data_counter
    }

    // Synchronous reset
    when (io.clear) {
        state := s_idle
        data_addr := 0.U
        data_size := 0.U
        data_size_woffset := 0.U
        byte_counter := 0.U
        data_counter := 0.U
    }

    // Acquire signals
    acquire.valid := state === s_store && (block_buffer.io.dout.valid || byte_counter >= data_size_woffset || byte_counter < data_offset)
    acquire.bits := edge.Put(
                    fromSource = 0.U,
                    toAddress = block_addr, 
                    lgSize = lgCacheBlockBytes.U, 
                    data = block_buffer.io.dout.bits,
                    mask = byte_mask)._2

    // Receive signals
    grant.ready := state === s_ack

    // Node signals
    io.done := state === s_done
    val ready_tmp = state === s_store && byte_counter >= data_offset && byte_counter < data_size_woffset && acquire.ready
    block_buffer.io.dout.ready := ready_tmp

    block_buffer.io.din.bits := io.node.bits.data
    block_buffer.io.din.valid := io.node.valid
    io.node.ready := block_buffer.io.din.ready

    block_buffer.io.clear := io.clear
    byte_mask := Mux(ready_tmp, (-1.S((xLen/8).W)).asUInt, 0.U)

    // Tie off unused channels
    tl_out.b.ready := true.B
    tl_out.c.valid := false.B
    tl_out.e.valid := false.B
}
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
import freechips.rocketchip.config.{Config, Parameters}
import freechips.rocketchip.diplomacy.LazyModule
import freechips.rocketchip.subsystem._
import freechips.rocketchip.tile.{BuildRoCC, OpcodeSet}


class DefaultOverlayConfig extends Config((site, here, up) => {
    case OverlayKey => OverlayParams(
        cellConfigBits = 192,
        inputNodes = 6,
        outputNodes = 6,
        fifoDepth = 32,
        blackBox = true
    )
})

class SimOverlayConfig extends Config((site, here, up) => {
    case OverlayKey => OverlayParams(
        cellConfigBits = 192,
        inputNodes = 3,
        outputNodes = 3,
        fifoDepth = 64,
        blackBox = false
    )
})

class WithOverlayRocc extends Config((site, here, up) => {
  case BuildRoCC => List(
    (p: Parameters) => {
        val overlay = LazyModule(new Overlay(OpcodeSet.custom0)(p))
        overlay
    }
  )
})

class DefaultDPROverlayConfig extends Config((site, here, up) => {
    case DPROverlayKey => DPROverlayParams(
        inputNodes = 6,
        outputNodes = 6,
        blackBox = true
    )
})

class WithDPROverlayRocc extends Config((site, here, up) => {
  case BuildRoCC => List(
    (p: Parameters) => {
        val overlay = LazyModule(new DPROverlay(OpcodeSet.custom0)(p))
        overlay
    }
  )
})
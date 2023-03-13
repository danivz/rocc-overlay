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
//  30/06/22                                                      //
//                                                                //
//  Centro de Electronica Industrial (CEI)                        //
//  Universidad Politecnica de Madrid (UPM)                       //
//                                                                //
////////////////////////////////////////////////////////////////////

module DPROverlayBlackBox

	#(parameter    C_DATA_WIDTH = 32, 
	               C_INPUT_NODES = 8, 
	               C_OUTPUT_NODES = 8)
	(
		input 	clock,
		input 	reset,

		input 	[C_DATA_WIDTH * C_INPUT_NODES - 1 : 0] 	data_in,
		input 	[C_INPUT_NODES - 1 : 0]					data_in_valid,
		output 	[C_INPUT_NODES - 1 : 0] 				data_in_ready,
		output 	[C_DATA_WIDTH * C_OUTPUT_NODES - 1 : 0] data_out,
		output 	[C_OUTPUT_NODES - 1 : 0]				data_out_valid,
		input 	[C_OUTPUT_NODES - 1 : 0] 				data_out_ready

	);

	dpr_overlay_rocc #(
		.C_DATA_WIDTH(C_DATA_WIDTH), 
		.C_INPUT_NODES(C_INPUT_NODES), 
		.C_OUTPUT_NODES(C_OUTPUT_NODES)
	) overlay_inst(
		.clk(clock),
		.reset(reset),
		.data_in(data_in),
		.data_in_valid(data_in_valid),
		.data_in_ready(data_in_ready),
		.data_out(data_out),
		.data_out_valid(data_out_valid),
		.data_out_ready(data_out_ready)
	);

endmodule
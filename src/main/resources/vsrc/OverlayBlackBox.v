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

module OverlayBlackBox

	#(parameter    C_FIXED_POINT = 0, 
	               C_FRACTION_LENGTH = 0, 
	               C_DATA_WIDTH = 32, 
	               C_INPUT_NODES = 8, 
	               C_OUTPUT_NODES = 8,
	               C_FIFO_DEPTH = 32)
	(
		input 				clock,
		input 				reset,
		input 	[191 : 0]	cell_config,

		input 	[C_DATA_WIDTH * C_INPUT_NODES - 1 : 0] 	data_in,
		input 	[C_INPUT_NODES - 1 : 0]					data_in_valid,
		output 	[C_INPUT_NODES - 1 : 0] 				data_in_ready,
		output 	[C_DATA_WIDTH * C_OUTPUT_NODES - 1 : 0] data_out,
		output 	[C_OUTPUT_NODES - 1 : 0]				data_out_valid,
		input 	[C_OUTPUT_NODES - 1 : 0] 				data_out_ready

	);

	overlay_rocc #(
		.C_FIXED_POINT(C_FIXED_POINT), 
		.C_FRACTION_LENGTH(C_FRACTION_LENGTH), 
		.C_DATA_WIDTH(C_DATA_WIDTH), 
		.C_INPUT_NODES(C_INPUT_NODES), 
		.C_OUTPUT_NODES(C_OUTPUT_NODES),
		.C_FIFO_DEPTH(C_FIFO_DEPTH)
	) overlay_inst(
		.clk(clock),
		.reset(reset),
		.data_in(data_in),
		.data_in_valid(data_in_valid),
		.data_in_ready(data_in_ready),
		.data_out(data_out),
		.data_out_valid(data_out_valid),
		.data_out_ready(data_out_ready),
		.cell_config(cell_config)
	);

endmodule
module synch_alif_neuron_wrap  #(

	localparam STATE_WIDTH = 32,
	localparam ARITHM_WIDTH = 8,
	localparam PARAM_WIDTH = 32,
	localparam SYN_WEIGHT_WIDTH = 4


	) (

	input                                      clk_i,    
	input                                      rst_ni,   
	input  logic        [                 2:0] spike_op_i,
	input  logic                               spike_i,
	input  logic        [                 7:0] time_i,
	input  logic signed [SYN_WEIGHT_WIDTH-1:0] syn_weight_i,
	input  logic        [SYN_WEIGHT_WIDTH-1:0] syn_weight_scale_i,
	input  logic        [     PARAM_WIDTH-1:0] neuron_param_i,
	output logic                               spike_o
	
);

logic [STATE_WIDTH-1:0] neuron_state_o;
logic [STATE_WIDTH-1:0] neuron_state_i;

alif_neuron #(

    .SYN_WEIGHT_WIDTH(SYN_WEIGHT_WIDTH),
    .ARITHM_WIDTH(ARITHM_WIDTH),
    .STATE_WIDTH(STATE_WIDTH),
    .PARAM_WIDTH(PARAM_WIDTH)

) neuron (
    .syn_weight_i       ( syn_weight_i       ),
    .syn_weight_scale_i ( syn_weight_scale_i ),
    .spike_i            ( spike_i            ),
    .spike_op_i         ( spike_op_i         ),
    .time_i             ( time_i             ),
    .mem_wipe_o         (                    ),
    .neuron_state_i     ( neuron_state_i     ),
    .neuron_param_i     ( neuron_param_i     ),
    .neuron_state_o     ( neuron_state_o     ),
    .spike_o            ( spike_o            )
);

always_ff @(posedge clk_i or negedge rst_ni) begin : proc_neuron_state_update
    if(~rst_ni) begin
        neuron_state_i <= 0;
    end else begin
        neuron_state_i <= neuron_state_o;
    end
end

endmodule
module neural_network_top (
    input CLOCK_50,
    input [1:0] KEY,   // Start signal (active low)
    input [9:0] SW,
    input Arduino_IO0,
    output [9:0] LEDR, // LEDs for state indication
    output [6:0] HEX0  // 7-segment display for output
);

    // Internal signals
    wire clk;
    wire clk_slow;
    wire start;
    wire resetn;
    wire done;
    wire [3:0] argmax_output;
    
    // State signals
    wire [3:0] current_state;
    wire [3:0] next_state;
    
    // Clock divider instance
    clock_divider clk_div (
        .clk_in(CLOCK_50),
        .clk_out(clk_slow),
        .DIVISOR(32'd500)  // Adjust this value to change clock speed
    );

    // Assign clock, start and reset
    assign clk = clk_slow;  // Use the slower clock
    assign start = ~KEY[0]; // KEY[0] is used for start
    assign resetn = SW[0];

    assign LEDR[9] = start;  // Shows if start is active
    assign LEDR[3:0] = current_state;  // Shows current state in binary

    // Neural network instance
    neural_network nn (
        .clk(clk),
        .clk2(CLOCK_50),
        .resetn(resetn),
        .start(start),
        .rx_serial(Arduino_IO0),
        .done(done),
        .current_state(current_state),
        .next_state(next_state),
        .argmax_output(argmax_output),
	.LEDR(LEDR[6:4])
    );
 
    DisplayNum display_hex(
	num(argmax_output),
	.hex(HEX0)
    );
	
endmodule

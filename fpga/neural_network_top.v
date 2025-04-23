module neural_network_top (
    input CLOCK_50,
    input [1:0] KEY,   // Start signal (active low)
    input [9:0] SW,
    input UART_RXD,    // UART RX pin
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
    wire [31:0] mm1_debug_data;
    wire [31:0] mm2_debug_data;
    wire [31:0] mm4_debug_data;
    wire [31:0] matrix1_data;

    // UART signals
    wire uart_data_ready;
    wire uart_data_valid;
    wire signed [31:0] uart_data [0:783];  // 784-element array for image data

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
    assign LEDR[8] = uart_data_ready;  // Shows when UART data is ready

    // UART data collector instance
    uart_data_collector #(
        .CLKS_PER_BIT(5209)  // For 50MHz clock and 9600 baud rate
    ) uart_collector (
        .i_Rst_L(resetn),
        .i_Clock(clk),
        .i_RX_Serial(UART_RXD),
        .o_Data_Ready(uart_data_ready),
        .o_Data_Valid(uart_data_valid),
        .o_Data(uart_data)
    );

    // Neural network instance
    neural_network nn (
        .clk(clk),
        .resetn(resetn),
        .start(start),
        .done(done),
        .current_state(current_state),
        .next_state(next_state),
        .argmax_output(argmax_output),
        .mm1_debug_data(mm1_debug_data),
        .mm2_debug_data(mm2_debug_data),
        .mm4_debug_data(mm4_debug_data),
        .image_data(uart_data),  // Connect UART data to neural network
        .image_valid(uart_data_valid)  // Connect UART data valid signal
    );

    DisplayNum display_hex(
        .num(argmax_output),
        .hex(HEX0)
    );

endmodule

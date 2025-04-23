module image_memory (
    input wire [15:0] address,
    output reg [31:0] data_out
);
    (* ram_init_file = "image_7.mif" *) reg signed [31:0] memory [0:783];  // 32-bit values

    always @(*) begin
        data_out = memory[address];
    end
endmodule
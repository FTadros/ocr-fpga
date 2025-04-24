module matrix3 (
    input wire [15:0] address,
    output reg signed [31:0] data_out
);
    (* ram_init_file = "weights3.mif" *) reg signed [31:0] memory [0:2047];  // 32-bit values

    always @(*) begin
        data_out = memory[address];
    end
endmodule
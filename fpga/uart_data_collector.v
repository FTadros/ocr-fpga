//////////////////////////////////////////////////////////////////////
// Description: This module uses the uart_rx module to receive 98 bytes
//              (784 bits) of data and stores them in a 784-element array
//              of 32-bit signed values. Each bit from the UART becomes one
//              32-bit value (0 or 1). When all data is received, o_Data_Ready
//              signal is asserted.
//
// Parameters:  Inherits CLKS_PER_BIT from uart_rx module
//
//////////////////////////////////////////////////////////////////////
module uart_data_collector
  #(parameter CLKS_PER_BIT = 5209)
  (
   input            i_Rst_L,
   input            i_Clock,
   input            i_RX_Serial,
   output           o_Data_Ready,
   output           o_Data_Valid,
   output reg signed [31:0] o_Data [0:783]
   );
  // Constants
  localparam BYTES_TO_RECEIVE = 98;  // 784 bits / 8 bits per byte = 98 bytes

  // State machine states
  localparam IDLE            = 2'b00;
  localparam RECEIVING_DATA  = 2'b01;
  localparam DATA_READY      = 2'b10;

  // Internal registers
  reg [1:0]  r_SM_Main;
  reg [6:0]  r_Byte_Count;      // Counter for received bytes (0-97, needs 7 bits)
  reg [2:0]  r_Bit_Index;       // Index within the current byte (0-7)
  reg        r_Data_Ready;
  reg        r_Data_Valid;
  reg signed [31:0] r_Data [0:783];  // 784 element array of 32-bit signed values

  // UART receiver connections
  wire       w_RX_DV;
  wire [7:0] w_RX_Byte;
  wire [7:0] w_RX_Byte_Hold;

  // Instantiate the UART Receiver
  uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) UART_RX_Inst
  (
   .i_Rst_L(i_Rst_L),
   .i_Clock(i_Clock),
   .i_RX_Serial(i_RX_Serial),
   .o_RX_DV(w_RX_DV),
   .o_RX_Byte(w_RX_Byte),
   .o_RX_Byte_Hold(w_RX_Byte_Hold)
  );

  integer i;  // For initialization

  // Main state machine
  always @(posedge i_Clock or negedge i_Rst_L)
  begin
    if (~i_Rst_L)
    begin
      r_SM_Main    <= IDLE;
      r_Byte_Count <= 0;
      r_Bit_Index  <= 0;
      r_Data_Ready <= 1'b0;
      r_Data_Valid <= 1'b0;

      // Initialize all elements to 0
      for (i = 0; i < 784; i = i + 1) begin
        r_Data[i] <= 32'h00000000;
      end
    end
    else
    begin
      case (r_SM_Main)

        IDLE:
        begin
          r_Data_Ready <= 1'b0;
          r_Data_Valid <= 1'b0;
          r_Byte_Count <= 0;
          r_Bit_Index  <= 0;

          if (w_RX_DV)  // Start receiving when first byte is detected
            r_SM_Main <= RECEIVING_DATA;
          else
            r_SM_Main <= IDLE;
        end

        RECEIVING_DATA:
        begin
          if (w_RX_DV)  // New byte received
          begin
            // Process each bit in the byte and store as a 32-bit value
            for (i = 0; i < 8; i = i + 1) begin
              // Calculate the correct index in the 784-element array
              // Each byte contributes 8 elements to the array
              if ((r_Byte_Count * 8 + i) < 784) begin
                // Extract bit i from the byte and convert to 32-bit signed value
                // If bit is 1, store 32'h00000001, else store 32'h00000000
                r_Data[r_Byte_Count * 8 + i] <= w_RX_Byte_Hold[i] ? 32'h00000001 : 32'h00000000;
              end
            end

            // Increment byte counter
            r_Byte_Count <= r_Byte_Count + 1;

            // Check if we've received all bytes
            if (r_Byte_Count == BYTES_TO_RECEIVE - 1)
            begin
              r_SM_Main <= DATA_READY;
            end
          end
        end

        DATA_READY:
        begin
          r_Data_Ready <= 1'b1;
          r_Data_Valid <= 1'b1;
          // Stay in this state until reset
          // Could add a return to IDLE if needed for continuous operation
        end

        default:
          r_SM_Main <= IDLE;

      endcase
    end
  end

  // Assign outputs
  assign o_Data_Ready = r_Data_Ready;
  assign o_Data_Valid = r_Data_Valid;

  // Output array is directly connected to the internal register array
  always @(*) begin
    for (i = 0; i < 784; i = i + 1) begin
      o_Data[i] = r_Data[i];
    end
  end

endmodule // uart_data_collector

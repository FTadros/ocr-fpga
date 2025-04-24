module uart_data_collector
  #(parameter CLKS_PER_BIT = 5209)
  (
   input            i_Rst_L,
   input            i_Clock,
   input            i_RX_Serial,
   input      [9:0] i_Data_Addr,    // Input address to select element (784 elements need 10 bits)
   output           o_Data_Ready,
   output           o_Data_Valid,
   output reg signed [31:0] o_Data_Element,  // Single element output
	output [2:0] LED
   );
  // Constants
  localparam BYTES_TO_RECEIVE = 98;  // 784 bits / 8 bits per byte = 98 bytes
 
  // State machine states
  localparam IDLE            = 2'b00;
  localparam RECEIVING_DATA  = 2'b01;
  localparam DATA_READY      = 2'b10;
  
  //State Latching
  reg [7:0] r_Received_Byte;
  reg r_Byte_Received;
 
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
 
  // Output the requested data element
  always @(*) begin
	  if (r_Data_Valid)
		 o_Data_Element = r_Data[i_Data_Addr];
	  else
		 o_Data_Element = 32'd0;  // or high-Z if tristate output
	end

	always @(posedge i_Clock or negedge i_Rst_L) begin
	  if (~i_Rst_L) begin
		 r_Byte_Received <= 1'b0;
		 r_Received_Byte <= 8'd0;
	  end else begin
		 r_Byte_Received <= w_RX_DV;
		 if (w_RX_DV)
			r_Received_Byte <= w_RX_Byte_Hold;
	  end
	end
 
  // Main state machine (rest remains the same)
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
         
          if (r_Byte_Received)  // Start receiving when first byte is detected
            r_SM_Main <= RECEIVING_DATA;
          else
            r_SM_Main <= IDLE;
        end
       
        RECEIVING_DATA:
        begin
          if (r_Byte_Received)  // New byte received
          begin
            // Process each bit in the byte and store as a 32-bit value
            for (i = 0; i < 8; i = i + 1) begin
              // Calculate the correct index in the 784-element array
              // Each byte contributes 8 elements to the array
              if ((r_Byte_Count * 8 + i) < 784) begin
                // Extract bit i from the byte and convert to 32-bit signed value
                // If bit is 1, store 32'h00000001, else store 32'h00000000
                r_Data[r_Byte_Count * 8 + i] <= r_Received_Byte[i] ? 32'h00000001 : 32'h00000000;
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
        end
       
        default:
          r_SM_Main <= IDLE;
         
      endcase
    end
  end
  
 
  // Assign outputs
  assign o_Data_Ready = r_Data_Ready;
  assign o_Data_Valid = r_Data_Valid;
  
  assign LED = (r_SM_Main == IDLE)         ? 3'b001 :
             (r_SM_Main == RECEIVING_DATA) ? 3'b010 :
             (r_SM_Main == DATA_READY)     ? 3'b100 :
                                             3'b000;  // Default/fallback; 
endmodule

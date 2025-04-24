module DisplayNum (
  input [3:0] num,
  output [7:0] hex
);  // 7 segment display module


  reg [7:0] seg7_display;
  assign hex = seg7_display;
  
  always @(num) begin
    case (num)
      0: seg7_display = 8'b11000000;
      1: seg7_display = 8'b11111001;
      2: seg7_display = 8'b10100100;
      3: seg7_display = 8'b10110000;
      4: seg7_display = 8'b10011001;
      5: seg7_display = 8'b10010010;
      6: seg7_display = 8'b10000010;
      7: seg7_display = 8'b11111000;
      8: seg7_display = 8'b10000000;
      9: seg7_display = 8'b10010000;
      default: seg7_display = 8'b11111111; //OFF
    endcase
  end
endmodule
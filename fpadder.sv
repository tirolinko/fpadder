module fpadder (output logic [31:0] sum, output logic ready,
		 input logic [31:0] a, input logic clock, nreset);

logic signA, signB;
logic [7:0] expA, expB;
logic [23:0] mantissaA, mantissaB;
logic [24:0] denormSum;
logic [4:0] normalizeCounter;
              
enum {reset, start, loada, loadb, checkSpecial, denormalize, adding, subtracting, normalizeAdd1, normalizeAdd2, normalizeSub1, normalizeSub2} state;

always_ff @(posedge clock, negedge nreset)
begin: SEQ
if (~nreset)
state <= reset;
else
begin  
case(state)

reset: begin
  signA <= '0;
  signB <= '0;
  mantissaA <= '0;
  mantissaB <= '0;
  expA <= '0;
  expB <= '0;
  sum <= '0;
  denormSum <= '0;
  normalizeCounter <= '0;
  state <= start;
end

start: begin
  normalizeCounter <= '0;
  state <= loada;
  end

  loada: begin
  sum <= 0;
  signA <= a[31];
  expA <= a[30:23];
  mantissaA[23:1] <= a[22:0];
  state <= loadb;
  end

  loadb: begin
  signB <= a[31];
  expB <= a[30:23];
  mantissaB[23:1] <= a[22:0];
  state <= checkSpecial;
end

checkSpecial : begin        
  //Check for special cases:
  //If A is NaN
  if((expA == 8'b11111111) && (mantissaA[23:1] != 23'b00000000000000000000000))
  begin
  sum <= 32'b11111111111111111111111111111111; //NaN
  state <= start;
  end
  else if((expB == 8'b11111111) && (mantissaB[23:1] != 23'b00000000000000000000000))
  begin
  sum <= 32'b11111111111111111111111111111111; //NaN
  state <= start;
  end
  //If trying to sum positive and negative infinity
  else if((expA == 8'b11111111) && (expB == 8'b11111111) && (signA != signB))
  begin
  sum <= 32'b11111111111111111111111111111111; //NaN
  state <= start;
  end
  //If A is infinity, and B is NOT the opposite infinity
  else if(expA == 8'b11111111)
  begin
  // Positive or negative Infinity depending on sign bit
  sum <= {signA, 31'b1111111100000000000000000000000}; // Positive or negative Infinity
  state <= start;
  end
  //If B is infinity, and A is NOT the opposite infinity
  else if(expB == 8'b11111111)
  begin
  // Positive or negative Infinity depending on sign bit
  sum <= {signB, 31'b1111111100000000000000000000000}; // Positive or negative Infinity
  state <= start;
  end
  //If statements for either input being 0, skipping calculation and going straight to answer.
  else if({expA, mantissaA[23:1]} == '0) 
  begin
  sum <= {signB, expB, mantissaB[23:1]};
  state <= start;
  end
  else if({expB, mantissaB[23:1]} == '0)
  begin
  sum <= {signA, expA, mantissaA[23:1]};
  state <= start;
  end
  else
  state <= denormalize;
end

denormalize : begin
  //Align exponents
  if (expA < expB)
  begin
  mantissaA[23:0] <= {1'b1, mantissaA[23:1]} >> (expB-expA);
  mantissaB[23:0] <= {1'b1, mantissaB[23:1]};
  sum[30:23] <= expB;
  end
  else
  begin
  mantissaB[23:0] <= {1'b1, mantissaB[23:1]} >> (expA-expB);
  mantissaA[23:0] <= {1'b1, mantissaA[23:1]};
  sum[30:23] <= expA;
  end
  //If both signs are the same, perform addition      
  if(signA == signB)
  begin
  state <= adding;
  end
  //If signs are different, perform subtraction
  else
  begin
  state <= subtracting;
  end
end

adding: begin
  denormSum[24:0] <= mantissaA[23:0] + mantissaB[23:0]; //maybe comb
  sum[31] <= signA;
  state <= normalizeAdd1;
end

normalizeAdd1: begin
  //If exponent has been increased by 1 due to addition
  if(denormSum[24])
  begin
  sum[30:23] <= sum[30:23] + 1'b1;
  sum[22:0] <= denormSum[23:1];
  end
  else
  sum[22:0] <= denormSum[22:0];

  state <= normalizeAdd2;
end

normalizeAdd2: begin
  //Check for overflow to infinity
  if(sum[30:23] == 8'b11111111)
  sum[30:0] <= 31'b1111111100000000000000000000000;

  state <= start;
end

subtracting: begin
  //Twos complement inversion of negative number
  if(mantissaA[23:0] == '0)
  begin
  sum <= {signB, expB, mantissaB[22:0]};
  state <= start;
  end
  else if(mantissaB[23:0] == '0)
  begin
  sum <= {signA, expA, mantissaA[22:0]};
  state <= start;
  end
  else if(signA)
  begin
  denormSum <= {signA, (~mantissaA[23:0] + 1'b1)} + {signB, mantissaB[23:0]};
  state <= normalizeSub1;
  end
  else
  begin
  denormSum <= {signA, mantissaA[23:0]} + {signB, (~mantissaB[23:0] + 1'b1)};
  state <= normalizeSub1;
end

end

normalizeSub1: begin
  //Check if result is 0
  if(denormSum[23:0] == '0)
  begin
  sum <= 0;
  state <= start;
  end
  else 
  //Check if the result is negative, in order to invert
  begin
  if (denormSum[24])
  begin
  denormSum[23:0] <= ~denormSum[23:0] + 1'b1;
  sum[31] <= denormSum[24];
  end
  state <= normalizeSub2;
  end
end

normalizeSub2: begin
  if(~denormSum[23])
  begin
  denormSum[23:0] <= denormSum[23:0] << 1;
  sum[30:23] <= sum[30:23] - 1'b1;
  normalizeCounter <= normalizeCounter + 1'b1;
  state <= normalizeSub2;
  end
  else
  begin
  sum[22:0] <= denormSum[22:0];
  state <= start;
  end
end

endcase
end
end
  
always_comb
begin: COM
  ready = '0;
  case(state)
  reset : begin
  ready = '0;
  end
  start : begin
  ready = '1;
  end
  default : begin
  ready = '0;
  end
  endcase
  end

endmodule

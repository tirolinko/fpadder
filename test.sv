module test;

logic [31:0] sum; 
logic ready;
logic [31:0] a;
logic clock, nreset;

fpadder a1 (.*);

shortreal reala, realsum;

initial
  begin
  nreset = '1;
  clock = '0;
  forever #5ns clock = ~clock;
  end

initial
  begin
  #5ns nreset = '0;
  #5ns nreset = '1;
  end
  
initial
  begin
  @(posedge ready); // wait for ready
  
  //Test 
  @(posedge clock); //wait for next clock tick
  reala = 42.135;
  a = $shortrealtobits(reala);
  @(posedge clock);
  reala = -0.135;
  a = $shortrealtobits(reala);
  @(posedge ready);
  @(posedge clock);
  realsum = $bitstoshortreal(sum);
  $display("Test %f\n", realsum);
  end
endmodule
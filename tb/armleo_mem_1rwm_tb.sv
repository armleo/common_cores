////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2016-2021, Arman Avetisyan
// 
////////////////////////////////////////////////////////////////////////////////

`define TOP_TB armleo_mem_1rwm_tb
`define TIMEOUT 100000
`define SYNC_RST
`define CLK_HALF_PERIOD 1

`include "armleo_template.svh"
`include "armleo_access_packed.svh"

localparam WIDTH = 16;
localparam DEPTH_LOG2 = 3;
localparam GRANULITY = 1;
localparam ENABLES = WIDTH/GRANULITY;

reg [DEPTH_LOG2-1:0] address;
reg read;
wire[WIDTH-1:0] readdata;
reg write;
reg [WIDTH-1:0] writedata;
reg [ENABLES-1:0] writeenable;

armleo_mem_1rwm #(
	.DEPTH_LOG2(DEPTH_LOG2),
	.WIDTH(WIDTH),
	.GRANULITY(GRANULITY)
) dut (
	.*
);




reg read_done = 0;
reg [DEPTH_LOG2-1:0] current_read_addr;
reg [WIDTH-1:0] current_readdata;



task next_cycle;
begin
	@(negedge clk);
	read = 0;
	write = 0;
	if(read_done) begin
		`assert_equal(readdata, current_readdata)
	end
end
endtask

integer m;
task write_req;
input [DEPTH_LOG2-1:0] addr;
input [WIDTH-1:0] dat;
input [ENABLES-1:0] strb;
begin
	write = 1;
	writedata = dat;
	address = addr;
	writeenable = strb;
	for(m = 0; m < ENABLES; m = m + 1)
		if(strb[m])
			mem[addr][`ACCESS_PACKED(m, GRANULITY)] = writedata[`ACCESS_PACKED(m, GRANULITY)];
end
endtask


reg [WIDTH-1:0] mem[2**DEPTH_LOG2 -1:0];

localparam DEPTH = 2**DEPTH_LOG2;

task read_req;
input [DEPTH_LOG2-1:0] addr;
begin
	read = 1;
	address = addr;
	current_readdata = mem[addr];
	next_cycle();

	read_done = 1;
	current_read_addr = addr;
	`assert_equal(readdata, current_readdata)
end
endtask



reg [DEPTH_LOG2-1:0] word;
reg [WIDTH-1:0] value_to_write;
reg [ENABLES-1:0] strb;

integer i;
initial begin
	read = 0;
	write = 0;
	writeenable = {(ENABLES){1'b1}};
	next_cycle();

	$display("Test Read should be keeping its value after write, write part");
	write_req(0, 0, {(ENABLES){1'b1}});
	next_cycle();

	$display("Test Read should be keeping its value after write, read part");
	read_req(0);
	next_cycle();
	
	$display("Test Read should be keeping its value after write, read part 2, without write");
	next_cycle();

	$display("Test Read should be keeping its value after write, write part 2, overwrite");
	write_req(0, 1, {(ENABLES){1'b1}});
	next_cycle();


	$display("Test write multiple data");
	for(i = 0; i < 2**DEPTH_LOG2; i = i + 1) begin
		word = $random % (2**WIDTH);
		//strb = $random % (2**(ENABLES));
		write_req(i, word, {(ENABLES){1'b1}});
		next_cycle();

		if(i < 10)
			$display("mem[%d] = 0x%x", i, mem[i]);
	end
	

	$display("Test read multiple data after modification");
	for(i = 0; i < 2**DEPTH_LOG2; i = i + 1) begin
		read_req(i);
		next_cycle();

		write_req(i, 0, {(ENABLES){1'b1}});
		next_cycle();

		write_req(i, 1, {(ENABLES){1'b1}});
		next_cycle();

		write_req(i, mem[i], {(ENABLES){1'b1}});
		next_cycle();
	end

	$display("Test random read write");

	for(i = 0; i < 1000; i = i + 1) begin
		word = $urandom() % (DEPTH);
		strb = $urandom() % (1 << ENABLES);
		value_to_write = $urandom() & ((2 ** WIDTH) - 1);
		if($urandom() & 1) begin
			$display("Random write addr = %d, data = 0x%x, strb = 0x%x", word, value_to_write, strb);
			
			write_req(word, //addr
					value_to_write,
					strb
				);
			next_cycle();
		end else begin
			
			read_req(word);
			next_cycle();
			$display("Random read addr = %d, data = 0x%x, got value: 0x%x", word, mem[word], readdata);
		end
	end
	$finish;
end


endmodule
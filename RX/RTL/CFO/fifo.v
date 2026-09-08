module fifo #(
    parameter depth=128,
    parameter WIDTH=16
)(
    input clk,reset,rd_en,wr_en,
    input [WIDTH-1:0]inreal,
    input [WIDTH-1:0]iimag,
    output reg[WIDTH-1:0]oureal,
    output reg[WIDTH-1:0]ouimag,
    output wire fifo_full
);
    reg [WIDTH*2-1:0]register[0:depth-1];
    parameter ptr_length=$clog2(depth);
    reg [ptr_length-1:0]rd_ptr;
    reg [ptr_length:0]wr_ptr;
    assign fifo_full= (wr_ptr == depth);
    always@(posedge clk or negedge reset )
    begin
        if(!reset)
        begin
            wr_ptr<=0;
            rd_ptr<=0;
        end
        else if(wr_en)
        begin 
        register[wr_ptr]<={inreal,iimag};
        wr_ptr<=wr_ptr+1;
        end
    end
    always@(posedge clk)
    begin
        if(rd_en)
        begin 
        {oureal,ouimag}<=register[rd_ptr];
        rd_ptr<=rd_ptr+1;
        end
    end
    endmodule
implement MatrixServer;
include "sys.m";
sys: Sys;
Connection: import Sys;
include "draw.m";
include "rand.m";
rand: Rand;

input_data_stream: chan of (int,int,int,array of int,array of int);
output_data_stream: chan of (int,int,int);

MatrixServer: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string){
	sys = load Sys Sys->PATH;
	rand = load Rand Rand->PATH;
	rand -> init(sys->millisec());

	(n,conn) := sys->announce("tcp!*!6666");

	if(n < 0)
	{
		sys->print("Announce failed!\n");
		exit;
	}

	while(1)
	{
		listen(conn);
	}

	multiplication_setup();
}

listen(conn: Connection)
{
	buf := array [sys->ATOMICIO] of byte;
	(status,c) := sys->listen(conn);
	if(status < 0)
	{
		sys->print("Listen failed!\n");
		exit;
	}
	rfd := sys->open(conn.dir+"/remote",Sys->OREAD);
	n := sys->read(rfd,buf,len buf);
	sys->print("Connection!");
	spawn handler(c);
}

handler(conn: Connection)
{
	buf := array [sys->ATOMICIO] of byte;
	rdfd := sys->open(conn.dir+"/data",Sys->OREAD);
	wdfd := sys->open(conn.dir+"/data",Sys->OWRITE);
	rfd := sys->open(conn.dir+"/remote",Sys->OREAD);

	n:= sys->read(rfd,buf,len buf);
	sys->print("Connection!");

	while(sys->read(rdfd,buf,len buf) >= 0)
	{
		sys->write(wdfd,array of byte "TEST DATA!\n",len "TEST DATA!\n");
		return;
	}
}


multiplication_setup()
{
	first_size_x := 3;
	first_size_y := 2;

	second_size_x := 2;
	second_size_y := 3;

	input_data_stream = chan of (int,int,int,array of int,array of int);
	output_data_stream = chan of (int,int,int);

	recieved_matrix1 : array of array of int;
	recieved_matrix2 : array of array of int;

	result_matrix : array of array of int;
	result_matrix = array[first_size_x] of {* => array[second_size_y] of {* => 0}};

	sys->print("Server started...\n");

	(recieved_matrix1,recieved_matrix2) = matrix_generation(first_size_x,first_size_y,second_size_x,second_size_y);
	
	sys->print("Multiplication process started...\n");
	
	result_matrix = multiply(first_size_x,first_size_y,second_size_y,recieved_matrix1,recieved_matrix2);

	sys->print("Multiplication process finished.\n");

	sys->print("Result matrix :\n");
	print_matrix(first_size_x,second_size_y,result_matrix);
}

matrix_generation(fsx: int,fsy: int,ssx: int,ssy: int) : (array of array of int,array of array of int)
{
	generated_matrix1 : array of array of int;
	generated_matrix1 = array[fsx] of {* => array[fsy] of {* => rand->rand(100)}};
	
	sys->print("Matrix 1:\n");
	print_matrix(fsx,fsy,generated_matrix1);

	generated_matrix2 : array of array of int;
	generated_matrix2 = array[ssx] of {* => array[ssy] of {* => rand->rand(100)}};

	sys->print("Matrix 2:\n");
	print_matrix(ssx,ssy,generated_matrix2);

	return (generated_matrix1,generated_matrix2);
}

print_matrix(sizex: int,sizey: int,matrix: array of array of int)
{
	for(p:=0;p<sizex;p++){
		for(h:=0;h<sizey;h++)
			sys->print("%d ",matrix[p][h]);
		sys->print("\n");
	}
}

multiply(fsx: int, fsy: int, ssy: int, matrix1 : array of array of int,matrix2 : array of array of int) : array of array of int
{
	result_matrix : array of array of int;
	result_matrix = array[fsx] of {* => array[ssy] of {* => 0}};

	for(th:=0;th<2;th++){
		spawn thread(input_data_stream, th);
	}

	col : array of int;
	col = array[fsy] of {* => 0};

	ret_i : int;
	ret_j : int;
	ret_result : int;

	i := 0;
	j := 0;
	for(y:=0;y<(fsx*ssy*2);y++){
		for(w:=0;w<fsy;w++)
			col[w] = matrix2[w][j];
		if(i!=fsx){
			alt
			{
				input_data_stream <-= (i,j,fsy,matrix1[i],col) =>
				{
					#sys->print("Send to I: %d, J: %d\n",i,j);
					j++;
					if(j>=ssy){
						j=0;
						i++;
					}
				}
				(ret_i,ret_j,ret_result) =<- output_data_stream =>
				{
					#sys->print("Result from I: %d, J: %d Result: %d\n",ret_i,ret_j,ret_result);
					result_matrix[ret_i][ret_j] = ret_result;
				}
			}
		}
		else{
			(ret_i,ret_j,ret_result) =<- output_data_stream;	
			#sys->print("Result from I: %d, J: %d Result: %d\n",ret_i,ret_j,ret_result);
			result_matrix[ret_i][ret_j] = ret_result;
		}	
	}
	return result_matrix;
}

thread(input_data_stream:chan of (int,int,int,array of int,array of int), id: int){
	i : int;
	j : int;
	size : int;
	a : array of int;
	b : array of int;

	result := 0;
	while(1){
		(i,j,size,a,b) =<- input_data_stream;
		for(k:=0;k<size;k++)
			result = result + a[k]*b[k];
		output_data_stream <-= (i,j,result);
		result = 0;
	}
}


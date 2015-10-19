implement MatrixClient;
include "sys.m";
sys: Sys;
Connection: import Sys;
include "draw.m";
include "math.m";
math: Math;
include "rand.m";
rand: Rand;

MatrixClient: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	math = load Math Math->PATH;
	rand = load Rand Rand->PATH;
	rand -> init(sys->millisec());

	sys->print("Client started...\n");

	(n,conn) := sys->dial("tcp!127.0.0.1!6666",nil);

	if(n < 0){
		sys->print("Connection error!");
		exit;
	}

	first_size_x := 5;
	first_size_y := 5;

	second_size_x := 5;
	second_size_y := 5;

	matrix1 : array of array of int;
	matrix2 : array of array of int;

	(matrix1,matrix2) = matrix_generation(first_size_x,first_size_y,second_size_x,second_size_y);

	wdfd := sys->open(conn.dir+"/data",Sys->OWRITE);
	rdfd := sys->open(conn.dir+"/data",Sys->OREAD);
	rfd := sys->open(conn.dir+"/remote",Sys->OREAD);

	
	

	request := array[4] of int;
	request[0] = first_size_x;
	request[1] = first_size_y;
	request[2] = second_size_x;
	request[3] = second_size_y;

	req_bytes := int_array_to_byte_array(request);

	test_ints := byte_array_to_int_array(req_bytes);

	sys->write(wdfd,req_bytes,len req_bytes);
	sys->print("Request sent...\n");

	matrix1_bytes := int_array_to_byte_array(pack_matrix(first_size_x,first_size_y,matrix1));
	sys->write(wdfd,matrix1_bytes,len matrix1_bytes);
	sys->print("First matrix sent...\n");

	matrix2_bytes := int_array_to_byte_array(pack_matrix(second_size_x,second_size_y,matrix2));
	sys->write(wdfd,matrix2_bytes,len matrix2_bytes);
	sys->print("Second matrix sent...\n");

	sys->print("Waiting...\n");


	result_matrix_bytes := array[first_size_x*second_size_y*4] of byte;

	n2:= sys->read(rfd,result_matrix_bytes,len result_matrix_bytes);
	if(sys->read(rdfd,result_matrix_bytes,len result_matrix_bytes) >= 0){
		sys->print("Recieved reuslt! ...\n");
		packed_result := byte_array_to_int_array(result_matrix_bytes);
		unpacked_result := unpack_matrix(first_size_x,second_size_y,packed_result);
		print_matrix(first_size_x,second_size_y,unpacked_result);
	}
	else
	{
		sys->print("Error! ...\n");	
	}
}

int_array_to_byte_array(int_array: array of int) : array of byte {
	buf := array[(len int_array) * 4] of byte;
	math->export_int(buf, int_array);
	return buf;
} 

byte_array_to_int_array(bytes: array of byte) : array of int
{
	buf := array[(len bytes) / 4] of int;
	math->import_int(bytes, buf);
	return buf;
}

pack_matrix(sizex: int, sizey: int, matrix: array of array of int) : array of int {
	result := array[sizex*sizey] of int;
	pos := 0;
	for(i:=0;i<sizex;i++)
		for(j:=0;j<sizey;j++){
			result[pos] = matrix[i][j];
			pos++;
		}
	return result;
}

unpack_matrix(sizex: int, sizey: int, packed: array of int) : array of array of int {
	result := array[sizex] of {* => array[sizey] of {* => 0}};
	pos := 0;
	for(i:=0;i<sizex;i++)
		for(j:=0;j<sizey;j++){
			result[i][j]=packed[pos];
			pos++;
		}
	return result;
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
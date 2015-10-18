implement MatrixServer;
include "sys.m";
sys: Sys;
Connection: import Sys;
include "draw.m";
include "math.m";
math: Math;
include "rand.m";
rand: Rand;

NUMBER_OF_THREADS : con 16;

MatrixServer: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string){
	sys = load Sys Sys->PATH;
	math = load Math Math->PATH;
	rand = load Rand Rand->PATH;
	rand -> init(sys->millisec());



	#(matrix1,matrix2) := matrix_generation(4,5,5,4);


	#res := multiplication_setup(4,5,5,4,matrix1,matrix2);
	#sys->print("Result:\n");
	#print_matrix(4,4,res);


	(n,conn) := sys->announce("tcp!*!6666");

	if(n < 0){
		sys->print("Announce failed!\n");
		exit;
	}
	while(1){
		listen(conn);
	}
}

listen(conn: Connection){
	buf := array [sys->ATOMICIO] of byte;
	(status,c) := sys->listen(conn);
	if(status < 0){
		sys->print("Listen failed!\n");
		exit;
	}
	rfd := sys->open(conn.dir+"/remote",Sys->OREAD);
	n := sys->read(rfd,buf,len buf);
	sys->print("New connection!\n");
	spawn handler(c);
}

handler(conn: Connection){
	buf := array [16] of byte;
	rdfd := sys->open(conn.dir+"/data",Sys->OREAD);
	wdfd := sys->open(conn.dir+"/data",Sys->OWRITE);
	rfd := sys->open(conn.dir+"/remote",Sys->OREAD);

	n:= sys->read(rfd,buf,len buf);

	request : array of int;
	while(sys->read(rdfd,buf,len buf) >= 0){
		request = byte_array_to_int_array(buf[0:16]);
		sys->print("Request accepted! M1: %dx%d M2: %dx%d\n",request[0],request[1],request[2],request[3]);
		break;
	}

	recieved_matrix1 : array of array of int;
	recieved_matrix2 : array of array of int;

	packed_matrix1_bytes:=array[request[0]*request[1]*4] of byte;
	packed_matrix2_bytes:=array[request[2]*request[3]*4] of byte;

	while(sys->read(rdfd,packed_matrix1_bytes,len packed_matrix1_bytes) >= 0){
		recieved_matrix1 = unpack_matrix(request[0],request[1],byte_array_to_int_array(packed_matrix1_bytes));
		break;
	}

	while(sys->read(rdfd,packed_matrix2_bytes,len packed_matrix2_bytes) >= 0){
		recieved_matrix2 = unpack_matrix(request[2],request[3],byte_array_to_int_array(packed_matrix2_bytes));
		break;
	}

	sys->print("Recieved both matrices!\n");
	sys->print("Starting multiplication...\n");

	result_matrix : array of array of int;



	#sys->print("M1:\n");
	#print_matrix(request[0],request[1],recieved_matrix1);

	#sys->print("M2:\n");
	#print_matrix(request[2],request[3],recieved_matrix2);

	result_matrix = multiplication_setup(request[0],request[1],request[2],request[3],recieved_matrix1,recieved_matrix2);

	sys->print("Result matrix :\n");
	#print_matrix(request[0],request[3],result_matrix);
}


multiplication_setup(first_size_x: int, first_size_y: int, second_size_x: int, second_size_y: int,recieved_matrix1: array of array of int,recieved_matrix2: array of array of int) : array of array of int {
	input_data_stream := chan of (int,int,int,array of int,array of int);
	output_data_stream := chan of (int,int,int);

	result_matrix := multiply(input_data_stream,output_data_stream,first_size_x,first_size_y,second_size_y,recieved_matrix1,recieved_matrix2);
	return result_matrix;
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

matrix_generation(fsx: int, fsy: int, ssx: int, ssy: int) : (array of array of int,array of array of int){
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

print_matrix(sizex: int,sizey: int,matrix: array of array of int){
	for(p:=0;p<sizex;p++){
		for(h:=0;h<sizey;h++)
			sys->print("%d ",matrix[p][h]);
		sys->print("\n");
	}
}

multiply(ids: chan of (int,int,int,array of int,array of int), ods: chan of (int,int,int),fsx: int, fsy: int, ssy: int, matrix1 : array of array of int,matrix2 : array of array of int) : array of array of int {
	result_matrix : array of array of int;
	result_matrix = array[fsx] of {* => array[ssy] of {* => 0}};

	for(th:=0;th<NUMBER_OF_THREADS;th++){
		spawn thread(ids,ods,th);
	}

	col : array of int;
	row : array of int;


	ret_i : int;
	ret_j : int;
	ret_result : int;

	i := 0;
	j := 0;
	for(y:=0;y<(fsx*ssy*2);y++){

		
		if(i!=fsx){
			col = array[fsy] of {* => 0};
			row = array[fsy] of {* => 0};
			for(r:=0;r<fsy;r++)
			{
				row[r] = matrix1[i][r];
			}
				
			for(w:=0;w<fsy;w++)
			{
				col[w] = matrix2[w][j];
			}
				
			alt
			{
				ids <-= (i,j,fsy,row,col) =>
				{
					#sys->print("Send to I: %d, J: %d\n",i,j);
					#for(it:=0;it<fsy;it++)
					#	sys->print("%d ",row[it]);
					#sys->print("\n");
					#for(it2:=0;it2<fsy;it2++)
					#	sys->print("%d ",col[it2]);
					#sys->print("\n");

					j++;
					if(j==ssy){
						j=0;
						i++;
					}

				}
				(ret_i,ret_j,ret_result) =<-ods =>
				{
					#sys->print("Result from I: %d, J: %d Result: %d\n",ret_i,ret_j,ret_result);
					result_matrix[ret_i][ret_j] = ret_result;
					ret_i = 0;
					ret_j = 0;
					ret_result = 0;
				}
			}
		} else {
			(ret_i,ret_j,ret_result) =<- ods;	
			#sys->print("Else Result from I: %d, J: %d Result: %d\n",ret_i,ret_j,ret_result);
			result_matrix[ret_i][ret_j] = ret_result;
			ret_i = 0;
			ret_j = 0;
			ret_result = 0;
		}	
	}
	return result_matrix;
}

thread(ids:chan of (int,int,int,array of int,array of int), ods: chan of (int,int,int), id: int){
	i := 0;
	j := 0;
	size := 0;
	a : array of int;
	b : array of int;

	result := 0;
	while(1){
		(i,j,size,a,b) =<- ids;

		for(k:=0;k<size;k++)
		{
			result = result + a[k]*b[k];
		}
			
		ods<-= (i,j,result);
		
		#for(u:=0;u<size;u++)
		#	sys->print("%d:%d[%d] %d %d  \n",i,j,u,a[u],b[u]);
		

		result = 0;
		i = 0;
		j = 0;
	}
}


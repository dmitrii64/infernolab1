implement MatrixServer;
include "sys.m";
	sys: Sys;
include "draw.m";
include "rand.m";
	rand: Rand;

MATRIX_SIZE : con 4;

input_data_stream: chan of (int,int,int,array of int,array of int);
output_data_stream: chan of (int,int,int);

MatrixServer: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	rand = load Rand Rand->PATH;
	rand -> init(sys->millisec());

	input_data_stream = chan of (int,int,int,array of int,array of int);
	output_data_stream = chan of (int,int,int);

	sys->print("Server started...\n");
	recieved_matrix1 : array of array of int;
	recieved_matrix1 = array[MATRIX_SIZE] of {* => array[MATRIX_SIZE] of {* => rand->rand(100)}};
	
	sys->print("Matrix 1:\n");

	for(p:=0;p<MATRIX_SIZE;p++){
		for(h:=0;h<MATRIX_SIZE;h++)
			sys->print("%d ",recieved_matrix1[p][h]);
		sys->print("\n");
	}

    recieved_matrix2 : array of array of int;
	recieved_matrix2 = array[MATRIX_SIZE] of {* => array[MATRIX_SIZE] of {* => rand->rand(100)}};

	sys->print("Matrix 2:\n");

	for(p=0;p<MATRIX_SIZE;p++){
		for(h:=0;h<MATRIX_SIZE;h++)
			sys->print("%d ",recieved_matrix2[p][h]);
		sys->print("\n");
	}

	result_matrix : array of array of int;
	result_matrix = array[MATRIX_SIZE] of {* => array[MATRIX_SIZE] of {* => 0}};

	sys->print("Multiplication process started...\n");
	
	result_matrix = multiply(recieved_matrix1,recieved_matrix2);

	sys->print("Multiplication process finished.\n");

	sys->print("Result matrix :\n");

	for(p=0;p<MATRIX_SIZE;p++)
	{
		for(h:=0;h<MATRIX_SIZE;h++)
			sys->print("%d ",result_matrix[p][h]);
		sys->print("\n");
	}
}

multiply(matrix1 : array of array of int,matrix2 : array of array of int) : array of array of int
{
	result_matrix : array of array of int;
	result_matrix = array[MATRIX_SIZE] of {* => array[MATRIX_SIZE] of {* => 0}};

	for(th:=0;th<2;th++)
	{
		spawn thread(input_data_stream, th);
	}

	col : array of int;
	col = array[MATRIX_SIZE] of {* => 0};

	ret_i : int;
	ret_j : int;
	ret_result : int;

	i := 0;
	j := 0;
	for(y:=0;y<(MATRIX_SIZE*MATRIX_SIZE*2);y++)
	{
		for(w:=0;w<MATRIX_SIZE;w++)
			col[w] = matrix2[w][j];
		if(i!=MATRIX_SIZE)
		{
			alt
			{
				input_data_stream <-= (i,j,MATRIX_SIZE,matrix1[i],col) =>
				{
					#sys->print("Send to I: %d, J: %d\n",i,j);
					j++;
					if(j>=MATRIX_SIZE){
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
		else
		{
			(ret_i,ret_j,ret_result) =<- output_data_stream;	
			#sys->print("Result from I: %d, J: %d Result: %d\n",ret_i,ret_j,ret_result);
			result_matrix[ret_i][ret_j] = ret_result;
		}	
	}
	return result_matrix;
}

thread(input_data_stream:chan of (int,int,int,array of int,array of int), id: int)
{
	i : int;
	j : int;
	size : int;
	a : array of int;
	b : array of int;

	result := 0;
	while(1)
	{
		(i,j,size,a,b) =<- input_data_stream;
		for(k:=0;k<size;k++)
			result = result + a[k]*b[k];
		output_data_stream <-= (i,j,result);
		result = 0;
	}
}


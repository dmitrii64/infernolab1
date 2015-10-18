implement MatrixServer;
include "sys.m";
sys: Sys;
include "draw.m";
include "rand.m";
rand: Rand;

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

	first_size_x := 3;
	first_size_y := 2;

	second_size_x := 2;
	second_size_y := 3;

	input_data_stream = chan of (int,int,int,array of int,array of int);
	output_data_stream = chan of (int,int,int);

	sys->print("Server started...\n");
	recieved_matrix1 : array of array of int;
	recieved_matrix1 = array[first_size_x] of {* => array[first_size_y] of {* => rand->rand(100)}};
	
	sys->print("Matrix 1:\n");

	for(p:=0;p<first_size_x;p++){
		for(h:=0;h<first_size_y;h++)
			sys->print("%d ",recieved_matrix1[p][h]);
		sys->print("\n");
	}

	recieved_matrix2 : array of array of int;
	recieved_matrix2 = array[second_size_x] of {* => array[second_size_y] of {* => rand->rand(100)}};

	sys->print("Matrix 2:\n");

	for(p=0;p<second_size_x;p++){
		for(h:=0;h<second_size_y;h++)
			sys->print("%d ",recieved_matrix2[p][h]);
		sys->print("\n");
	}

	result_matrix : array of array of int;
	result_matrix = array[first_size_x] of {* => array[second_size_y] of {* => 0}};

	sys->print("Multiplication process started...\n");
	
	result_matrix = multiply(first_size_x,first_size_y,second_size_y,recieved_matrix1,recieved_matrix2);

	sys->print("Multiplication process finished.\n");

	sys->print("Result matrix :\n");

	for(p=0;p<first_size_x;p++)
	{
		for(h:=0;h<second_size_y;h++)
			sys->print("%d ",result_matrix[p][h]);
		sys->print("\n");
	}
}

multiply(fsx: int, fsy: int, ssy: int, matrix1 : array of array of int,matrix2 : array of array of int) : array of array of int
{
	result_matrix : array of array of int;
	result_matrix = array[fsx] of {* => array[ssy] of {* => 0}};

	for(th:=0;th<2;th++)
	{
		spawn thread(input_data_stream, th);
	}

	col : array of int;
	col = array[fsy] of {* => 0};

	ret_i : int;
	ret_j : int;
	ret_result : int;

	i := 0;
	j := 0;
	for(y:=0;y<(fsx*ssy*2);y++)
	{
		for(w:=0;w<fsy;w++)
			col[w] = matrix2[w][j];
		if(i!=fsx)
		{
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


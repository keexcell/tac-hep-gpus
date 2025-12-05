#include <stdio.h>
#include <iostream>
#include <cstdlib>

const int DSIZE = 512;
const int radius = 3;
const int A_val = 2;
const int B_val = 3;


void stencil_2d(const int in[][DSIZE], int out[][DSIZE]) {
	for (int x_index = 0; x_index < DSIZE; x_index++) {
		for (int y_index  = 0; y_index < DSIZE; y_index++) {
			int in_cell = in[x_index][y_index];
			if (x_index < radius || x_index + radius >= DSIZE) {
				out[x_index][y_index] = in_cell;
			}
			else if (y_index < radius || y_index + radius >= DSIZE) {
				out[x_index][y_index] = in_cell;
			}
			else {
				int temp_sum = 0;
				for (int offset = -radius; offset <= radius; offset++) {
					temp_sum +=  in[x_index + offset][y_index];
					temp_sum +=  in[x_index][y_index+offset];
				}
				temp_sum -= in_cell;  //avoid double counting
				out[x_index][y_index] = temp_sum;
			}
		}
	}
}

int stencil_checker(const int A_out[][DSIZE], const int B_out[][DSIZE]){
	for (int i = 0; i < DSIZE; ++i) {
		for (int j = 0; j < DSIZE; ++j) {
			if (i < radius || i + radius >= DSIZE) {
				if (A_out[i][j] != A_val) {
					printf("A: mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, A_out[i][j], A_val);
					return -1;
				}
				if (B_out[i][j] != B_val) {
                    printf("B: mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, B_out[i][j], B_val);
                    return -1;
                }
			}
			else if (j < radius || j + radius >= DSIZE) {
				if (A_out[i][j] != A_val) {
                    printf("A: mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, A_out[i][j], A_val);
                    return -1;
                }
                if (B_out[i][j] != B_val) {
                    printf("B: mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, B_out[i][j], B_val);
                    return -1;
                }
			
			}
			else {
				if (A_out[i][j] != A_val + A_val*4*radius) {
					printf("A: mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, A_out[i][j], A_val + A_val*4*radius);
					return -1;
				}
				 if (B_out[i][j] != B_val + B_val*4*radius) {
                    printf("B: mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, B_out[i][j], B_val + B_val*4*radius);
                    return -1;
                    }
			}
		}
	}
	return 0;
}


void matrix_mult(const int A[][DSIZE], const int B[][DSIZE], int C[][DSIZE], int size) {
	int Atemp[DSIZE*DSIZE];
	int Btemp[DSIZE*DSIZE];
	for (int r=0; r<size; r++) {
		for (int c=0; c<size; c++) {
			Atemp[r*DSIZE + c] = A[r][c];
			Btemp[r*DSIZE + c] = B[r][c];
		}
	}
	for (int r=0; r<size; r++) {
		for (int c=0; c<size; c++) {
			int sum = 0;
			for (int i=0; i<size; i++) {
				sum += Atemp[r*size + i]*Btemp[i*size + c];
			}
			C[r][c] = sum;
		}
	}
}

int mult_checker(const int A[][DSIZE], const int B[][DSIZE], const int C[][DSIZE]){
	int A_stenc_val = A_val + A_val*4*radius;
	int B_stenc_val = B_val + B_val*4*radius;
	int DSIZE_mid = DSIZE - 2*radius;
	for (int i = 0; i < DSIZE; ++i) {
		for (int j = 0; j < DSIZE; ++j) {
			if ((i < radius || i + radius >= DSIZE) && (j < radius || j + radius >= DSIZE)){
				if (C[i][j] != A_val*B_val*DSIZE){
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[i][j], A_val*B_val*DSIZE);
					return -1;
				}
			}
			else if ((i < radius || i + radius >= DSIZE) && (j >= radius && j + radius < DSIZE)){
				if (C[i][j] != A_val*B_val*2*radius + A_val*B_stenc_val*DSIZE_mid){
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[i][j], A_val*B_val*2*radius + A_val*B_stenc_val*DSIZE_mid);
					return -1;
				}
			}
			else if ((i >= radius && i + radius < DSIZE) && (j >= radius && j + radius < DSIZE)){
				if (C[i][j] != A_val*B_val*2*radius + A_stenc_val*B_stenc_val*DSIZE_mid){
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[i][j], A_val*B_val*2*radius + A_stenc_val*B_stenc_val*DSIZE_mid);
					return -1;
				}
			}
			else{
				if (C[i][j] != A_val*B_val*2*radius + A_stenc_val*B_val*DSIZE_mid){
					printf("Mismatch at index [%d,%d], was: %d, should be: %d\n", i,j, C[i][j], A_val*B_val*2*radius + A_stenc_val*B_val*DSIZE_mid);
					return -1;
				}
			}
		}
	}
	return 0;
}


int main() {
	int A[DSIZE][DSIZE];
	int B[DSIZE][DSIZE];
	int A_stenc[DSIZE][DSIZE];
	int B_stenc[DSIZE][DSIZE];
	int C[DSIZE][DSIZE];
	for (int i = 0; i < (DSIZE); i++) {
		for (int j = 0; j < (DSIZE); j++) {
			A[i][j] = A_val;
			B[i][j] = B_val;
			A_stenc[i][j] = 0;
			B_stenc[i][j] = 0;
			C[i][j] = 0;
		}
	}

	//apply stencil to A and B
	stencil_2d(A, A_stenc);
	stencil_2d(B, B_stenc);
	//check
	stencil_checker(A_stenc, B_stenc);

	//multiply the stenciled matrices
	matrix_mult(A_stenc, B_stenc, C, DSIZE);
	//check
	mult_checker(A_stenc, B_stenc, C);
}

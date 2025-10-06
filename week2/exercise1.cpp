#include <iostream>

void swap_integers (int &a, int &b)
{
    int holder_a = a;
    a = b;
    b = holder_a;
}

int main()
{

    int A[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    int B[10] = {10, 9, 8, 7, 6, 5, 4, 3, 2, 1};
    
    //I wanted to check and it seems printing arrays is tricky in C++
    std::cout << "Before swapping: A = ";
    for (int i = 0; i < 10; i++) {
        std::cout << A[i] << " ";
    }
    std::cout << std::endl;
    std::cout << "Before swapping: B = ";
    for (int i = 0; i < 10; i++) {
        std::cout << B[i] << " ";
    }
    std::cout << std::endl << std::endl;
    
    //here lies my function usage
    for (int i = 0; i < 10; i++) {
        swap_integers(A[0], B[0]);
    }

    std::cout << "After swapping: A = ";
    for (int i = 0; i < 10; i++) {
        std::cout << A[i] << " ";
    }
    std::cout << std::endl;
    std::cout << "After swapping: B = ";
    for (int i = 0; i < 10; i++) {
        std::cout << B[i] << " ";
    }
    std::cout << std::endl << std::endl;
    
    return 0;
}

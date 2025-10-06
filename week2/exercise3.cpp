#include <iostream>
#include <string>

std::string rockpaperscissors(std::string shoot1, std::string shoot2)
{
    if ((shoot1 != "rock") && (shoot1 != "paper") && (shoot1 != "scissors"))
        return "Invalid input";
    else if ((shoot2 != "rock") && (shoot2 != "paper") && (shoot2 != "scissors"))
        return "Invalid input";
    else if (shoot1 == shoot2)
        return "Draw!";
    else if ((shoot1== "rock" && shoot2 == "scissors") 
            || (shoot1 == "scissors" && shoot2 == "paper") 
            || (shoot1 == "paper" && shoot2 == "rock"))
        return "Player 1 wins!";
    else
        return "Player 2 wins!";
        
}

int main()
{
    std::cout<<rockpaperscissors("boop", "rock") << std::endl;
    std::cout<<rockpaperscissors("rock", "rock") << std::endl;
    std::cout<<rockpaperscissors("scissors", "rock") << std::endl;
    std::cout<<rockpaperscissors("scissors", "beep") << std::endl;
    std::cout<<rockpaperscissors("rock", "scissors") << std::endl;

    return 0;
}


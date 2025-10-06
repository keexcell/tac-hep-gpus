#include <vector>
#include <string>
#include <iostream>

struct Student {
    std::string name;
    std::string university;
    int year;
    std::string experiment;
    std::vector<std::string> hobbies;
    std::string email;
};
void print_student_info(const Student &person) {
    std::cout << "Name: " << person.name << std::endl;
    std::cout << "University: " << person.university << std::endl;
    std::cout << "Year: " << person.year << std::endl;
    std::cout << "Experiment: " << person.experiment << std::endl;
    std::cout << "Hobbies: ";
    for (const std::string &hobby : person.hobbies) {
        std::cout << hobby << " ";
    }
    std::cout << std::endl;
    std::cout << "Email: " << person.email << std::endl;
}

int main()
{
    Student kayleigh = {"Kayleigh Excell", "UW-Madison", 2, "LSST", {"reading","sewing","baking"}, "kexcell@wisc.edu"};
    print_student_info(kayleigh);
    Student walker = {"Walker Sundquist", "UMass Amherst", 2, "Atlas", {"backpacking","weird art"}, "wsundquist@umass.edu"};
    print_student_info(walker);
    Student roy = {"Roy Cruz Cadelaria", "UW-Madison", 1, "CMS", {"gaming","painting","learning languages"}, "rfcruz@wisc.edu"};
    print_student_info(roy);
    Student taylor = {"Taylor Sussmane", "UW-Madison", 2, "CMS", {"reading","crafts", "bass guitar"}, "tsussmane@wisc.edu"};
    print_student_info(taylor);
    Student jenna = {"Jenna Roderick", "UW-Madison", 1, "CMS", {"thrifting","crocheting","walking"}, "jroderick2@wisc.edu"};
    print_student_info(jenna);
    Student max = {"Max Zhao", "Princeton", 2, "CMS", {"clarinet","rock climbing", "puzzles"}, "max.zhao@princeton.edu"};
    print_student_info(max);
    Student daniel = {"Daniel Humphreys", "UMass Amherst", 6, "Atlas", {"gaming","hiking","skiing", "reading", "volunteering"}, "dhumphreys@umass.edu"};
    print_student_info(daniel);
    Student daijon = {"DaiJon James", "UMass Amherst", 2, "Atlas", {}, "daijonjames@umass.edu"};
    print_student_info(daijon);
    Student kyla = {"Kyla Martinez", "UW-Madison", 2, "CMS", {"good food and drinks","puppy!"}, "kmartinez24@wisc.edu"};
    print_student_info(kyla);
    Student justin = {"Justin Marquez", "UW-Madison", 5, "CMS", {"reading","crocheting", "gaming"}, "justin.marquez@wisc.edu"};
    print_student_info(justin);
    Student elias = {"Elias Mettner", "UW-Madison", 1, "CMS", {"cooking GF","singing", "playing various instruments"}, "emettner@wisc.edu"};
    print_student_info(elias);
    Student julianne = {"Julianna Starzee", "UMass Amherst", 2, "Atlas", {"reading","writing", "playing instruments"}, "jstarzee@umass.edu"};
    print_student_info(julianne);
    
    return 0;
}

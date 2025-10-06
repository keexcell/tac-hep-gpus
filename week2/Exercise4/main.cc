#include <stdio.h>
#include <iostream>
#include <vector>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "hh/t1.h"

#include <TMath.h>
#include <TFile.h>
#include <TTree.h>
#include <TH1F.h>
#include <TCanvas.h> 
#include <TLorentzVector.h>




//------------------------------------------------------------------------------
// Particle Class
//
class Particle{

	public:
	Particle();
	double   pt, eta, phi, E, m, p[4];
	void     p4(double, double, double, double);
	void     print();
	void     setMass(double);
	double   sintheta();
	
	Particle(double pt, double eta, double phi, double E);
};

class Lepton : public Particle{
	public:
    	Lepton();
        int charge = 0;
	void setCharge(int);
	void print();
};

class Jet : public Particle{
   	public:
        Jet();
	int h_flavor = 0;
	void setFlavor(int);
	void print();
};

//------------------------------------------------------------------------------

//*****************************************************************************
//                                                                             *
//    MEMBERS functions of the Particle Class                                  *
//                                                                             *
//*****************************************************************************

//
//*** Default constructor ------------------------------------------------------
//
Particle::Particle(){
	pt = eta = phi = E = m = 0.0;
	p[0] = p[1] = p[2] = p[3] = 0.0;
}

//*** Additional constructor ------------------------------------------------------
Particle::Particle(double E, double px, double py, double pz){ 
	pt = eta = phi = E = m = 0.0;
	p[0]=E;
	p[1]=px;
	p[2]=py;
	p[3]=pz;
}

Lepton::Lepton(){
        pt = eta = phi = E = m = 0.0;
        p[0] = p[1] = p[2] = p[3] = 0.0;
	charge = 0;
}

Jet::Jet(){
        pt = eta = phi = E = m = 0.0;
        p[0] = p[1] = p[2] = p[3] = 0.0;
	h_flavor = 0;
}

//
//*** Members  ------------------------------------------------------
//
double Particle::sintheta(){
	/* got this formula from a combination of pseudorapidity’s wiki and 
https://dspace.mit.edu/bitstream/handle/1721.1/92036/Aad-2012-Measurement%20of%2
0the%20p.pdf?sequence=1 
where pT = |p|sin(theta) = |p|/cosh(eta) */
	return 1.0 / std::cosh(eta);
}

void Particle::p4(double pT, double eta, double phi, double energy){
    	pt = pT;
	eta = eta;
    	phi = phi;
    	E = energy; 
	p[0] = E;
	p[1] = pt * std::cos(phi);;
	p[2] = pt * std::sin(phi);
	p[3] = pt * std::sinh((eta));
    
}

void Particle::setMass(double mass)
{
	m = mass;
}

//
//*** Prints 4-vector ----------------------------------------------------------
//
void Particle::print(){
	std::cout << std::endl;
	std::cout << "(" << p[0] <<",\t" << p[1] <<",\t"<< p[2] <<",\t"<< p[3] << ")" << "  " <<  sintheta() << std::endl;
}

void Lepton::print(){
        std::cout << std::endl;
        std::cout << "(" << p[0] <<",\t" << p[1] <<",\t"<< p[2] <<",\t"<< p[3] << ")" << "  " <<  sintheta() << std::endl;
	std::cout << "Charge = " << charge << std::endl;
}

void Jet::print(){
        std::cout << std::endl;
        std::cout << "(" << p[0] <<",\t" << p[1] <<",\t"<< p[2] <<",\t"<< p[3] << ")" << "  " <<  sintheta() << std::endl;
	std::cout << "Hadron Flavor = " << h_flavor << std::endl;
}
void Lepton::setCharge(int chrge){
	charge = chrge;
}

void Jet::setFlavor(int h_flav){
    	h_flavor = h_flav;
}


int main() {
	
	/* ************* */
	/* Input Tree   */
	/* ************* */

	TFile *f      = new TFile("input.root","READ");
	TTree *t1 = (TTree*)(f->Get("t1"));

	// Read the variables from the ROOT tree branches
	t1->SetBranchAddress("nleps",&nleps);
	t1->SetBranchAddress("lepPt",&lepPt);
	t1->SetBranchAddress("lepEta",&lepEta);
	t1->SetBranchAddress("lepPhi",&lepPhi);
	t1->SetBranchAddress("lepE",&lepE);
	t1->SetBranchAddress("lepQ",&lepQ);
	
	t1->SetBranchAddress("njets",&njets);
	t1->SetBranchAddress("jetPt",&jetPt);
	t1->SetBranchAddress("jetEta",&jetEta);
	t1->SetBranchAddress("jetPhi",&jetPhi);
	t1->SetBranchAddress("jetE", &jetE);
	t1->SetBranchAddress("jetHadronFlavour",&jetHadronFlavour);

	// Total number of events in ROOT tree
	Long64_t nentries = t1->GetEntries();

	for (Long64_t jentry=0; jentry<10;jentry++)
 	{
		t1->GetEntry(jentry);
		std::cout<<" Event "<< jentry <<std::endl;
       	
        	for (int l_i = 0; l_i < nleps; ++l_i){
			Lepton lep_var = Lepton();
			lep_var.p4(lepPt[l_i], lepEta[l_i], lepPhi[l_i], lepE[l_i]);
			lep_var.setCharge(lepQ[l_i]);
			lep_var.print();
		} //loop over lepton events
		for (int j_i = 0; j_i < njets; ++j_i){
			Jet jet_var = Jet();
			jet_var.p4(jetPt[j_i], jetEta[j_i], jetPhi[j_i], jetE[j_i]);
			jet_var.setFlavor(jetHadronFlavour[j_i]);
			jet_var.print();
		} //loop over jet events
	
	
       	


	} // Loop over all events

  	return 0;
}

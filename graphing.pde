width = window.innerWidth-300;
height = window.innerHeight;

// constants
int FRAME_RATE = 30;
int OFFSET = 3;										// distance a node is inset from the edge when it runs off the screen

// user changeable constants
float FORCE_SCALE;									// functions as a global force scale so you don't have to ruin the ratio to change the magnitude (and therefore speed)
float GRAVITATIONAL_COEFFICIENT;
float FRICTION_COEFFICIENT;
int STEPS_PER_DRAW;									// defines calculations between redraws
float STEPS_PER_SECOND;								// gives steps per second or the delta T
float GRAV_DIST;
float SPRING_RELAXED_LENGTH;
float SPRING_CONSTANT;
int LINE_OPACITY;
int NUMBER_OF_NODES;
float CONNECTIONS_PER_NODE;
float MAX_BOOST;

float NODE_RADIUS = 15.0;
int LINE_WIDTH = 1;
color NODE_COLOR = color(166, 99, 41);
color LINE_COLOR = color(48, 115, 96, 255);
color BACKGROUND_COLOR = color(2, 81, 89);

float time = 0.0;
float potentialEnergy = 0.0;
int[][] adjacencyMatrix;
int[][] adjacentPairs;
PVector[] posArray;
PVector[] velArray;
PVector[] forceArray;
float[] lastDistances;	// an array containing the last lengths of the springs for conparison to this steps lengths as a check of completeness

////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// User Interaction ///////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

void boostAll() {														// give all points some random velocity
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		PVector boost = new PVector(random(-1*MAX_BOOST, MAX_BOOST), random(-1*MAX_BOOST, MAX_BOOST));
		velArray[i] = PVector.add(boost, velArray[i]);
	}
}

void restart() {
	noLoop();						// to stop it
	NUMBER_OF_NODES = int(document.getElementById('nodes').value);
	CONNECTIONS_PER_NODE = int(document.getElementById('connectionsPerNode').value);
	adjacencyMatrix = randomMatrix();
	adjacentPairs = pairsFromMatrix(adjacencyMatrix);
	setupConstants();	
	loop();							// start!
}

void replay() {
	noLoop();						// to stop it
	setupConstants();	
	loop();							// start!	
}

////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// Helpful Functions //////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

float sum(arr) {															// generates a sum over all the elements of an array
	float retVal = 0.0;
	
	for (int i = 0; i < arr.length; i++) {
		retVal += arr[i];
	}
	
	return retVal;
}

void setupConstants() {
	// prepare arrays and matrices for use	
	posArray = new PVector[NUMBER_OF_NODES];
	velArray = new PVector[NUMBER_OF_NODES];
	forceArray = new PVector[NUMBER_OF_NODES];
	
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		posArray[i] = new PVector((width/4)+NODE_RADIUS+random((width/2)), (height/4)+NODE_RADIUS+random((height/2)));
		velArray[i] = new PVector(0.0, 0.0);
		forceArray[i] = new PVector(0.0, 0.0);
	}
	
	// clear lastDistances
	lastDistances = null;
			
	// user enterables
	GRAV_DIST = float(document.getElementById('gravDist').value);
	SPRING_RELAXED_LENGTH = float(document.getElementById('springLength').value);
	SPRING_CONSTANT = float(document.getElementById('springCoeff').value);
	FORCE_SCALE = float(document.getElementById('forceScale').value);
	GRAVITATIONAL_COEFFICIENT = float(document.getElementById('repulsionCoeff').value);
	FRICTION_COEFFICIENT = float(document.getElementById('frictionCoeff').value);
	STEPS_PER_DRAW = int(document.getElementById('stepsPerDraw').value);
	STEPS_PER_SECOND = float(document.getElementById('stepsPerSec').value);
	MAX_BOOST = 30*GRAVITATIONAL_COEFFICIENT*FORCE_SCALE*SPRING_CONSTANT
	
	// colors
	LINE_OPACITY = int(document.getElementById('lineOpacity').value);
	LINE_COLOR = color(48, 115, 96, LINE_OPACITY);
	stroke(LINE_COLOR);

	// clear screen
	background(BACKGROUND_COLOR);
	
	// reset timing
	time = 0.0;
	frameCount = 0;
	displayCalcsPerSec(0);
	displayCalcs(0);
}

void displayCalcsPerSec(float calcsPerSec) {
	document.getElementById('calcsPerSec').innerText = "Calculations/second: "+int(calcsPerSec);
}

void displayCalcs(float calcs) {
	document.getElementById('calcs').innerText = "Calculations: "+int(calcs);
}

void displayEnergy(float energy) {
	document.getElementById('energy').innerText = "Potential Energy: "+int(energy);
}

////////////////////////////////////////////////////////////////////////////////////
///////////////// Random Matrix & Matrix processing Functions //////////////////////
////////////////////////////////////////////////////////////////////////////////////

// function to generate a random adjacency matrix
int[][] randomMatrix() {
	int[][] matrix = new int[NUMBER_OF_NODES][NUMBER_OF_NODES];
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		var toPush = new Array();
		for (int j = 0; j < NUMBER_OF_NODES; j++) {
			if (random(1) < CONNECTIONS_PER_NODE/float(NUMBER_OF_NODES) && i != j) {
				matrix[i][j] = 1;
				matrix[j][i] = 1;
			}
			else {
				matrix[i][j] = 0;
				matrix[j][i] = 0;
			}
		}
	}
	
	for (int i = 0; i < NUMBER_OF_NODES; i++) {										// give every ball at least one connection
		if (!sum(matrix[i])) {
			int rand = i;
			while (rand == i) {
				rand = int(random(NUMBER_OF_NODES));
			}
			matrix[i][rand] = 1;
			matrix[rand][i] = 1;
		}
	}
	return matrix
}

int[][] pairsFromMatrix(int[][] adjacencies) {
	var pairsArray = new Array();					// XXX: I really should avoid mixing processing and JS directly like this
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		for (int j = 0; j < i; j++) {
			if (adjacencies[i][j]) {
				toPush = new int[2];
				toPush[0] = i;
				toPush[1] = j;
				pairsArray.push(toPush)
			}
		}
	}
	
	int[][] retVal = new int[pairsArray.length][2];
	for(int i = 0; i < pairsArray.length; i++) {
		retVal[i] = pairsArray[i];
	}
	return retVal;
}

////////////////////////////////////////////////////////////////////////////////////
///////////////////////// Force Caclulating Functions //////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

PVector springForce(PVector myPos, PVector yourPos) {
	PVector result = PVector.sub(yourPos, myPos);

	// apply a relaxed length
	float angle = PVector.angleBetween(new PVector(1.0, 0.0), result);
	if (result.x < 0) {
		result.x += abs(SPRING_RELAXED_LENGTH*cos(angle));
	}
	else {
		result.x -= abs(SPRING_RELAXED_LENGTH*cos(angle));
	}
	if (result.y < 0) {
		result.y += abs(SPRING_RELAXED_LENGTH*sin(angle));
	}
	else {
		result.y -= abs(SPRING_RELAXED_LENGTH*sin(angle));
	}
	
	float dist = sqrt(result.x*result.x, result.y*result.y);
	result.z = 0.5*dist*dist;
	result.mult(SPRING_CONSTANT/float(CONNECTIONS_PER_NODE/NUMBER_OF_NODES));
	return result;
}

PVector repulseForce(PVector myPos, PVector yourPos) {
	float dist = PVector.dist(myPos, yourPos);
	float coeff = GRAVITATIONAL_COEFFICIENT/(dist*dist*dist);
	float potEnergy = GRAVITATIONAL_COEFFICIENT/dist;
	PVector result = PVector.sub(myPos, yourPos);
	result.mult(coeff);
	result.z = potEnergy;
	return result;
}

PVector frictionForce(PVector myVel) {
	return PVector.mult(myVel, FRICTION_COEFFICIENT);
}

////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Force Adding Functions ////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

void addRepulsionForces() {
	for (int i = 1; i < NUMBER_OF_NODES; i++) {
		for (int j = 0; j < i; j++) {
			PVector posI = posArray[i];
			PVector posJ = posArray[j];
			float dist = PVector.dist(posI, posJ);
			if (dist>NODE_RADIUS/10 && dist < GRAV_DIST) {
				PVector repulse = repulseForce(posI, posJ);
				potentialEnergy += 2.0*repulse.z;			// add the potential energy due to this interaction
				repulse.z = 0.0;
				forceArray[i].add(repulse);					// add the force on the first node
				forceArray[j].add(PVector.mult(repulse, -1.0));		// add the opposite to the second node
			}
		}
	}
}

void addSpringForces() {
	for (int i = 0; i < adjacentPairs.length; i++) {
		int indexOne = adjacentPairs[i][0];
		int indexTwo = adjacentPairs[i][1];
		PVector posOne = posArray[indexOne];
		PVector posTwo = posArray[indexTwo];
		PVector spring = springForce(posOne, posTwo);
		potentialEnergy += 2.0 * spring.z;								// add the potential energy dye to this interaction
		spring.z = 0.0;
		forceArray[indexOne].add(spring);								// add the force on the first node
		forceArray[indexTwo].add(PVector.mult(spring, -1.0));			// add the force on the second node
	}
}

void addFrictionForces() {
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		forceArray[i].add(frictionForce(velArray[i]));
	}
}

////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////// step method /////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////

void step() {
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		PVector force = forceArray[i];
		PVector vel = velArray[i];
		PVector pos = posArray[i];
						
		PVector delAccel = PVector.mult(force, (FORCE_SCALE/float(STEPS_PER_SECOND)));
		PVector delVel = PVector.mult(vel, (1.0/float(STEPS_PER_SECOND)));
		
		pos.add(delVel);
		vel.add(delAccel);

		if (pos.x < NODE_RADIUS) {
			pos.x = NODE_RADIUS + OFFSET;
		}
		else if (pos.x > width-1 - NODE_RADIUS) {
			pos.x = width - 1 - NODE_RADIUS - OFFSET;
		}
		if (pos.y < NODE_RADIUS) {
			pos.y = NODE_RADIUS + OFFSET;
		}
		else if (pos.y > height - NODE_RADIUS) {
			pos.y = height - NODE_RADIUS - OFFSET;
		}
		
		posArray[i] = pos;
		velArray[i] = vel;
		
		forceArray[i] = new PVector(0.0, 0.0);				// zeroing the force array before the next calculation
	}
}

////////////////////////////////////////////////////////////////////////////////////
/////////////////////// Calculation and Drawing Functions //////////////////////////
////////////////////////////////////////////////////////////////////////////////////

void calculate() {
	float startTime = new Date().getTime();
	
	for (int i = 0; i < STEPS_PER_DRAW-1; i++) {
		addRepulsionForces();
		addSpringForces();
		addFrictionForces();
		step();								// applies the forces to the velocities and velocities to the positions
	}
	
	potentialEnergy = 0.0;					// on the last step we calculate the potential energy
	
	addRepulsionForces();
	addSpringForces();
	addFrictionForces();
	step();								// applies the forces to the velocities and velocities to the positions
		
	float endTime = new Date().getTime();
	time += (endTime - startTime);
}

void drawAll() {
	background(BACKGROUND_COLOR);			// erase
	
	for (int i = 0; i < NUMBER_OF_NODES; i++) {
		PVector pos = posArray[i];
		ellipse(pos.x, pos.y, NODE_RADIUS, NODE_RADIUS);			// draw the node
	}
	
	drawLines(i);			// draw all the edges
}

void drawLines(int index) {
	for(int i = 0; i < adjacentPairs.length; i++) {
		PVector posOne = posArray[adjacentPairs[i][0]];
		PVector posTwo = posArray[adjacentPairs[i][1]];
		float theta = PVector.angleBetween(PVector.sub(posOne, posTwo), new PVector(1, 0));
		float xFix = (0.5*NODE_RADIUS*cos(theta));
		float yFix = (0.5*NODE_RADIUS*sin(theta));
		float yFixTwo = yFix;
		if (posOne.y > posTwo.y) {
			yFixTwo = -yFix;
		}
		if (posOne.y < posTwo.y) {
			yFix = - yFix;
		}
		line(posOne.x-xFix, posOne.y+yFixTwo, posTwo.x+xFix, posTwo.y+yFix);
	}
}

////////////////////////////////////////////////////////////////////////////////////
//////////////////////// Processing.js Running Functions ///////////////////////////
////////////////////////////////////////////////////////////////////////////////////

void setup() {
	NUMBER_OF_NODES = int(document.getElementById('nodes').value);
	CONNECTIONS_PER_NODE = int(document.getElementById('connectionsPerNode').value);

	adjacencyMatrix = randomMatrix();
	adjacentPairs = pairsFromMatrix(adjacencyMatrix);

	size(width, height);
	strokeWeight(LINE_WIDTH);
	fill(NODE_COLOR);
	frameRate(FRAME_RATE);
	
	setupConstants();
}

void draw() {
	calculate();
	displayCalcs(frameCount*STEPS_PER_DRAW);
	
	displayEnergy(potentialEnergy);
	
	if (!(frameCount%(int(FRAME_RATE/2)))) {													// display an averaged time per step every half second
		displayCalcsPerSec((frameCount*STEPS_PER_DRAW)/(time/1000.0));
	}
	
	drawAll();	
}
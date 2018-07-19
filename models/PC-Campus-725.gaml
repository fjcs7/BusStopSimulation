/**
* Name: PCCampus725
* Author: Fernando Junio
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model PCCampus725

global{

	//preenchendo os dados da ordem das bus_stops(paradas)
	list<pair<string,int>> stopList;
	list<pair<int,point>> stopsLocation; 
	map<bus_route, float> roads_weight;
	int nrPassengerForStop <- 20;
	float distance_to_intercept <- 3.0;
	int nrOfBuses <- 1;
	list<string> simulationsTypes <- ["direct","twoBusDirect","alternatingStops"]; 
	string typeSimulation <- "direct";
	bool intermintentStop;
	int nbBuses<- 2;


	//map used to filter the object to build from the OSM file according to attributes. for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
	//map filtering <- map(["highway"::["primary", "secondary", "tertiary", "motorway", "living_street","residential", "unclassified"], "building"::["yes"]]);
	//map filtering <- map(["highway"::["yes"], "building"::["yes"]]);
	//OSM file to load
	file<geometry> osmfile <-  file<geometry>("../Mapas/UFG-PCCampus.osm");
	//compute the size of the environment from the envelope of the OSM file
	geometry shape <- envelope(osmfile);
	graph bus_network; 
	
	init {
		//possibility to load all of the attibutes of the OSM data: for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
		create osm_agent from:osmfile with: [bus_route_str::string(read("route")),
											 highway_str::string(read("highway")), 
			                                 bus_stop_str::string(read("public_transport"))];
											
		//Adding bus stop sequence at list of stops
		add ('4774'::1) to: stopList;
		add ('3353'::2) to: stopList;
		add ('3355'::3) to: stopList;
		add ('6363'::4) to: stopList;
		add ('6364'::5) to: stopList;
		add ('6365'::6) to: stopList;
		add ('3359'::7) to: stopList;
		add ('3360'::8) to: stopList;
		add ('3361'::9) to: stopList;
		add ('3358'::10) to: stopList;
		add ('6366'::11) to: stopList;
		add ('6367'::12) to: stopList;
		add ('3356'::13) to: stopList;
		add ('3354'::14) to: stopList;
		add ('3379'::15) to: stopList; 	
		
		//from the created generic agents, creation of the selected agents
		bool slow;
		ask osm_agent {
			if (highway_str != nil ) {
				//here contains all ways
				create road with: [shape ::shape, 
								   type:: "road",
								   name:: name];
			}else if (bus_stop_str != nil){
				 pair busStopData <- stopList first_with (each.key = name);
				 if(busStopData.value != 0){
					 if (bus_stop_str = "stop_position"){
					 	int nrDoPonto <- busStopData.value;
					 	//Adding number point and stop location
					 	add pair<int,point>(nrDoPonto::shape) to: stopsLocation;
					 	create bus_stop with:[shape ::shape, 
					 		                  type:: "bus_stop",
					 		                  name:: busStopData.key,
					 		                  ref:: busStopData.value];
					 } 
				 }
			}else if (bus_route_str != nil){
				if (bus_route_str = "bus"){
					create bus_route with:[shape ::shape, 
										   type:: "bus_route",
										   name:: "pcCampusRoute"];
				} 
			}
			
			//do the generic agent die
			do die;
		}
		
		//Weights map of the graph for those who will know the shortest road by taking into account the weight of the edges
		roads_weight <- bus_route as_map (each:: each.shape.perimeter);
		bus_network <- directed(as_edge_graph(bus_route));
		list<int> nbInicialStop<- [1,7];
		loop nrValues from: 0 to: nbBuses -1 {
			create bus number:nbBuses with:[
				color :: #orange,
				size :: 6.0,
				route :: bus_route as_map (each:: each.shape.perimeter),
				firstStop:: (stopsLocation first_with (each.key = nbInicialStop[nrValues])).value,
				nextStop :: (stopsLocation first_with (each.key = nbInicialStop[nrValues]+1)).value
			];	
		}
		
		loop busStopsLocation over: stopsLocation{
			if(busStopsLocation.key != last(stopList).value){
				
				//Supose that one passenger goes to one of point destination betwen 2 or 7 points before hes arrive
				int minDestination <- busStopsLocation.key + 2;
				int maxDestination <- busStopsLocation.key + 7;

				if(minDestination > length(stopsLocation)){
					minDestination <- minDestination - length(stopsLocation);
					write("min: " + minDestination);
				}				

				if(maxDestination > length(stopsLocation)){
					maxDestination <- maxDestination - length(stopsLocation);
					write("max: " + maxDestination);
				}
				
				int pointNumber <- rnd(minDestination,maxDestination);
				if(pointNumber>15 or pointNumber <= 0){
					write(pointNumber);
				}
				pair<int, point> destinationPoint <- stopsLocation first_with (each.key = pointNumber) ;
				if(destinationPoint=(0::nil)){
					write(destinationPoint);
					write(pointNumber);
				}
				
				create passenger number: nrPassengerForStop  with: [
					size::0.5,
					stopDestination:: destinationPoint,
					location::busStopsLocation.value
				];
			}
		}
	}

	reflex stop_simulation when: (length(passenger)=0) {
		//Pause simulation when passengers numbers decrease for zero
		do pause;
	} 	
}

species osm_agent {
	string highway_str;
	string bus_stop_str;
	string bus_route_str;
} 
	
species road {
	rgb color <- #blue;
	string type;
	aspect default {
		draw shape color: color; 
	}
}

species bus_stop {
	rgb color <- #red;
	string usName;
	string type;
	int ref;
	aspect default {
		draw circle(3) color: color; 
	}
}

species bus_route {
	rgb color;
	string busRouteName;
	string type;
	aspect geom {
		draw shape color: #green;
	}
}

species bus skills: [moving] {
	int maxCapacity <- 50;
	rgb color <- #green;
	float size;
	map<bus_route, float> route; 
	
	int lotacao <- 0 min:0 update:length(self.passengers);
	bool paradaSolicitada;
	point firstStop;
	point nextStop;
	path path_to_follow;
	list<passenger> passengers;
	bool isFull <- false update:lotacao = maxCapacity;
	float busSpeed <- 5.0;
	int nrOfTravels <- 0;
	
	init {
		location <- firstStop;
	}
	
	reflex movement when: typeSimulation = "direct"
	{
		if(location != nextStop)
		{
			if (path_to_follow = nil) {
				//Find the shortest path using the agent's own weights to compute the shortest path
			   path_to_follow <- path_between (bus_network with_weights route, location,nextStop);
				//path_to_follow <- path_from_nodes(graph: bus_network, nodes: [location, nextStop]);
			}
			//the agent follows the path it computed but with the real weights of the graph
			do follow path:path_to_follow speed: busSpeed move_weights: roads_weight;
		} 
		else if(location = nextStop) 
		{
			int nrActualBusStop <- 1;
			loop times: 10* #cycle{
				write(#cycle);
			}
			speed <-0.0;
			if(nextStop != (stopsLocation first_with (each.key = last(stopList).value)).value){
				nrActualBusStop <- (stopsLocation first_with (each.value = nextStop)).key + 1;
			}
			//Select next bus_stop positon to go 
			point nextPoint <- (stopsLocation first_with (each.key = nrActualBusStop)).value;
			if(nextPoint!=nil){
				nextStop <- nextPoint;
				if(nrActualBusStop=1){
					location <- nextPoint;
					nrOfTravels <- nrOfTravels+1;
				}
				path_to_follow <- nil;	
			}
		}
	} 
		
	aspect base {
		draw circle(size) color: color;
	}
}

species passenger skills: [moving]{
	rgb color <- #black;
	float size;
	bus myBus <- nil;
	pair<int, point> stopDestination;
	
	init{
		speed <- 0.0;
	}
	
	reflex movement
	{
		if(myBus!=nil){
			location <- myBus.location;
			speed <- myBus.busSpeed;
			if(location=stopDestination.value){
				ask myBus{
					remove all: myself from:self.passengers;
					self.lotacao <- self.lotacao -1; 
				}
				do die;
			}
		}
	}
	
	aspect base {
		draw circle(size) color: color;
		ask bus at_distance(distance_to_intercept) {
			if(myself.myBus=nil){
				if(not (length(self.passengers)=self.maxCapacity)){
					//Adding bus at passenger
					myself.myBus <- self;
					//Add passenger at list of bus passengers
					add myself to: self.passengers;
				}
			}
		}
	}
}  

experiment BusExperiment type: gui {
	float cycle <- 60 #seconds;
	
	output {
		display map type: opengl {
			species road refresh: true  ;
			species bus_route refresh: true aspect: geom ;
			species bus_stop refresh: true ;
			species bus refresh: true aspect: base;
			species passenger refresh: true  aspect: base;
		}
	}
}

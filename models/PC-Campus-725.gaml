/**
* Name: PCCampus725
* Author: Fernando Junio
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model PCCampus725

global{

	//preenchendo os dados da ordem das bus_stops(paradas)
	list<pair<string,int>> listaDeParadas;
	list<pair<int,point>> localizacaoDasParadas; 
	bus_route rotaBus;
	map<bus_route, float> roads_weight;


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
											
		listaDeParadas <- listaDeParadas + [pair<string,int>('4774'::1)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3353'::2)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3355'::3)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('6363'::4)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('6364'::5)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('6365'::6)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3359'::7)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3360'::8)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3361'::9)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3358'::10)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('6366'::11)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('6367'::12)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3356'::13)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3354'::14)];
		listaDeParadas <- listaDeParadas + [pair<string,int>('3379'::15)];
		
		//from the created generic agents, creation of the selected agents
		bool slow;
		ask osm_agent {
			if (highway_str != nil ) {
				//here contains all ways
				create road with: [shape ::shape, 
								   type:: "road",
								   name:: name];
			}else if (bus_stop_str != nil){
				 pair dadosDoPonto <- listaDeParadas first_with (each.key = name);
				 if(dadosDoPonto.value != 0){
					 if (bus_stop_str = "stop_position"){
					 	int nrDoPonto <- dadosDoPonto.value;
					 	localizacaoDasParadas <- localizacaoDasParadas + [pair<int,point>(nrDoPonto::shape)] ;
					 	create bus_stop with:[shape ::shape, 
					 		                  type:: "bus_stop",
					 		                  name:: dadosDoPonto.key,
					 		                  ref:: dadosDoPonto.value];
					 } 
				 }
			}else if (bus_route_str != nil){
				 if (bus_route_str = "bus"){
				 	create bus_route with:[shape ::shape, 
				 						   type:: "bus_route",
				 						   name:: "pcCampusRoute"] ;
				 } 
			}
			
			//do the generic agent die
			do die;
		}
		
		//Weights map of the graph for those who will know the shortest road by taking into account the weight of the edges
		roads_weight <- bus_route as_map (each:: each.shape.perimeter);
		bus_network <- as_edge_graph(bus_route);
		
		create bus  with:[
			color :: #orange,
			size :: 6.0,
			route :: bus_route as_map (each:: each.shape.perimeter)
		];

	}	
}


species osm_agent {
	string highway_str;
	string bus_stop_str;
	string bus_route_str;
} 
	
species road {
	rgb color <- #blue;
	string name;
	string type;
	aspect default {
		draw shape color: color; 
	}
}

species bus_stop {
	rgb color <- #red;
	string name;
	string type;
	int ref;
	aspect default {
		draw circle(3) color: color; 
	}
}

species bus_route {
	rgb color;
	string name;
	string type;
	aspect geom {
		draw shape color: #green;
	}
}

species bus skills: [moving] {
	rgb color <- #green;
	float size;
	map<bus_route, float> route; 
	
	int lotacao <- 0 min:0 max:50;
	bool paradaSolicitada;
	point firstStop;
	point nextStop;
	path path_to_follow;
	
	init {
		firstStop <- (localizacaoDasParadas first_with (each.key = 1)).value;
		nextStop <- (localizacaoDasParadas first_with (each.key = 2)).value;
		location <- firstStop;
	}
	
	reflex movement 
	{
		if(location != nextStop)
		{
			write("DiferentyWay");
			if (path_to_follow = nil) {
				//Find the shortest path using the agent's own weights to compute the shortest path
				path_to_follow <- path_between(bus_network with_weights route, location,nextStop);
			}
			//the agent follows the path it computed but with the real weights of the graph
			do follow path:path_to_follow speed: 5.0 move_weights: roads_weight;
		} 
		else if(location = nextStop) 
		{
			write("NewWay");
			if(nextStop != (localizacaoDasParadas first_with (each.key = last(listaDeParadas).value)).value){
				int nrActualBusStop <- (localizacaoDasParadas first_with (each.value = nextStop)).key + 1;
				//Select next bus_stop positon to go 
				point nextPoint <- (localizacaoDasParadas first_with (each.key = nrActualBusStop)).value;
				if(nextPoint!=nil){
					nextStop <- nextPoint;
					path_to_follow <- nil;	
				}
			}
		}
	} 
		
	aspect base {
		draw circle(size) color: color;
	}
}  

experiment load_OSM type: gui {
	float minimum_cycle_duration <- 0.1;
	output {
		display map type: opengl {
			species road refresh: false  ;
			species bus_route aspect: geom ;
			species bus_stop refresh: false ;
			species bus aspect: base;
		}
	}
}


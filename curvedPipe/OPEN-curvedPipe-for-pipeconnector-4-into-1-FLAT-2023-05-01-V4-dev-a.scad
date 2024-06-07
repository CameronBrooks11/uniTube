// from: https://jantecnl.synology.me/en/joining-multiple-hollow-bending-tubes-in-openscad-with-curvedpipe-libs/

use <vector.scad>;   // Author: Juan Gonzalez-Gomez, GPL
use <maths.scad>;   // Author: William A Adams, Public Domain
use <moreShapes.scad>;    // Author: Damian Axford, with elements by nophead, Public Domain

fudge = 0.01;

// result is u-v
function subv(u,v) = [u[0]-v[0], u[1]-v[1], u[2]-v[2]];

function vec3_from_vec4(v) = [v[0], v[1], v[2]];
function vec4_from_vec3(v) = [v[0], v[1], v[2], 1];

module pipeOrientate(v1,v2)
{
	// calc rotation for v1	
	v1axis = v1[0]==0 && v1[1] == 0 ? [0,1,0] : cross([0,0,1], v1);    // condition accounts for v1 being aligned with z axis
	v1ang = anglev([0,0,1], v1);
		
	v1axisLen = mod(v1axis);
	
	// v2 as vec4	
	vec2 = vec4_from_vec3(v2);
	
	// make quat to reverse the final rotation
	qRev = quat(v1axis, v1ang);
	qRevMat = quat_to_mat4(qRev);

	// rotate v2 by qRev
	vec2Rev = v1axisLen>0 ? vec4_mult_mat4(vec2, qRevMat) : vec2;

	// look and x,y components of vec2Rev and calc rot about z
	theta = atan2(vec2Rev[1], vec2Rev[0]);
	
	// complete the two rotations
    rotate(a=v1ang, v=v1axis)
	  rotate(a=theta<0 || theta>0?theta:0, v=[0,0,1])
         children(0);
}

// The following module does the actual WRITE function and is repeated as many times as required to write all pipes:
module pipeCurve(points,point,radii, od,id, segments,isLastSegment=false) {
	pre = points[point-1];
	start = points[point];
	mid = points[point+1];
	end = points[point+2];

	post = points[point+3];
	preR = radii[point-1];
	r = radii[point];	
	postR = radii[point+1];

	dir1 = subv(mid,start);
	dir2 = subv(end,mid);
	l1 = mod(dir1);
	l2 = mod(dir2);
	ang = anglev(dir1,dir2);

	preDir = pre? subv(start,pre) : dir1;
	preAng = pre? anglev(preDir, dir1) : 0;
	preInset = pre? preR * tan(preAng/2) : 0;
	
	postDir = post? subv(post,end) : dir2;
	postAng = post? anglev(dir2, postDir) : 0;
	postInset = post? postR * tan(postAng/2) : 0;
	
	dir1u = unitv(dir1);
	inset = r * tan(ang/2);
	rStart = start + (l1-inset)*dir1u;
	
	// start of the tubes write command
	translate(start) orientate(dir1)
    translate([0,0,preInset]) 
	tube(h=l1-preInset-inset,or=od/2, ir=id/2, center=false);
    
    // THE ACTUAL 'tube'WRITE ASSIGNMENT for the start of the pipe
    
// somewhere over here, a memory function needs to be built to NOT make a wall when it collides with the previous walls, and vice versa!  Then, the inner area of crossing pipes will remain empty, instead of blocked by the crossing pipe!  This can be best done by running each pipe section with numbered naming and use all others as cutouts for any run... Check for how the Internl diameter is cutoff, this might be useful as example as to WHERE put the cutoffs..  OR- an easier approach could be to just cutout ALL internal diameters for all pipes everywhere....

	//end of the tubes write command
	translate(mid) orientate(dir2) 
	translate([0,0,inset]) 
	tube(h=l2-postInset-inset,or=od/2, ir=id/2, center=false);// THE ACTUAL 'tube' WRITE ASSIGNMENT for the end of the pipe
	
	// curved section write command (repeated for each section) in between start and end
	// nb: torus slice always starts at x axis and goes counter clockwise around z
	translate(rStart) 
	pipeOrientate(dir1,dir2)
	rotate([0,0,180])  // rotate to lie along x
	rotate([90,0,0]) // flip up
    //difference(){
	translate([-r,0,0])torusSlice(r1=r, r2=od/2, r3=id/2, start_angle=0, end_angle=ang);
        
    //translate([-r,0,0])torusSlice_only_inner_pipes(r1=r, r2=od/2, r3=id/2, start_angle=0, end_angle=ang);
//}
    // THE ACTUAL 'torusSlice' WRITE ASSIGNMENT where we must solve the problem that the pipes block each other upon multiple pipes when bending in each other's way
    //torusSlice(r1=r, r2=od/2, start_angle=0, end_angle=ang, convexity=10, r3=id/2 ,
    //OR USE: torusSlice_only_inner_pipes  FOR THE CUTOUTS OF INNER PIPES
}



// The following module does the actual WRITE function of the pipe's curved coutouts for each part and is repeated as many times as required to write all pipes:
module pipeCurveCutout(points,point,radii, od,id, segments,isLastSegment=false) {
	pre = points[point-1];
	start = points[point];
	mid = points[point+1];
	end = points[point+2];

	post = points[point+3];
	preR = radii[point-1];
	r = radii[point];	
	postR = radii[point+1];

	dir1 = subv(mid,start);
	dir2 = subv(end,mid);
	l1 = mod(dir1);
	l2 = mod(dir2);
	ang = anglev(dir1,dir2);

	preDir = pre? subv(start,pre) : dir1;
	preAng = pre? anglev(preDir, dir1) : 0;
	preInset = pre? preR * tan(preAng/2) : 0;
	
	postDir = post? subv(post,end) : dir2;
	postAng = post? anglev(dir2, postDir) : 0;
	postInset = post? postR * tan(postAng/2) : 0;
	
	dir1u = unitv(dir1);
	inset = r * tan(ang/2);
	rStart = start + (l1-inset)*dir1u;
	
	// start of the tubes write command
	translate(start) orientate(dir1)
    translate([0,0,preInset]) tube(h=l1-preInset-inset,or=id/2, ir=0, center=false);
    
    
    
    // THE ACTUAL 'tube'WRITE ASSIGNMENT for the start of the pipe
    
// somewhere over here, a memory function needs to be built to NOT make a wall when it collides with the previous walls, and vice versa!  Then, the inner area of crossing pipes will remain empty, instead of blocked by the crossing pipe!  This can be best done by running each pipe section with numbered naming and use all others as cutouts for any run... Check for how the Internl diameter is cutoff, this might be useful as example as to WHERE put the cutoffs..  OR- an easier approach could be to just cutout ALL internal diameters for all pipes everywhere....

	//end of the tubes write command
	translate(mid) orientate(dir2) translate([0,0,inset]) tube(h=l2-postInset-inset,or=id/2, ir=0, center=false);// THE ACTUAL 'tube' WRITE ASSIGNMENT for the end of the pipe
	
	// curved section write command (repeated for each section) in between start and end
	// nb: torus slice always starts at x axis and goes counter clockwise around z
	translate(rStart) 
	pipeOrientate(dir1,dir2)
	rotate([0,0,180])  // rotate to lie along x
	rotate([90,0,0]) // flip up
    //difference(){
        
	translate([-r,0,0])torusSlice_only_inner_pipes(r1=r, r2=od/2, r3=id/2, start_angle=0, end_angle=ang);
    
    //TEST for cutout
    //translate([0,0,od/2]) cube([1000,1000,od],center=true);// test for showing lower 1/2 part of all the pipes 
    //translate([-r,0,0])torusSlice_only_inner_pipes(r1=r, r2=od/2, r3=id/2, start_angle=0, end_angle=ang);
//}
    // THE ACTUAL 'torusSlice' WRITE ASSIGNMENT where we must solve the problem that the pipes block each other upon multiple pipes when bending in each other's way
    //torusSlice(r1=r, r2=od/2, start_angle=0, end_angle=ang, convexity=10, r3=id/2 ,
    //OR USE: torusSlice_only_inner_pipes  FOR THE CUTOUTS OF INNER PIPES
}


// The following module does the actual WRITE function for the pipes and is repeated as many times as required to write all pipes:
module curvedPipe(points, segments, radii, od, id) {
	union() {
		for (point = [0:segments-2]) 
			pipeCurve(points,point,radii,od,id);
	}
}

//difference(){
    //curvedPipe_module(34,26,50);
    //curvedPipe_module (26,0,50);
    //translate([0,0,6]) cube([1000,1000,8],center=true);// test for showing lower 1/2 part of all the pipes  
//}


module curvedPipe_module(odia,idia,angle){
//the (curved if required) pipes to be made:
if (true) {
	curvedPipe([ 
[-30,0,0],// start point 1 coordinates x,y,z
[30,0,0],// point 2 coordinates x,y,z
[60,40,0],// point 3 coordinates x,y,z
[110,40,0]],// point 4 coordinates x,y,z    
3,// number of segments   
[angle,angle],// rev.angle between segments (0-1, 2-3, etc)
odia,//outer diameter of tube   
idia);//inner diameter of tube
    
      

	curvedPipe([ 
[-30,0,0],// start point 1 coordinates x,y,z
[30,0,0],// point 2 coordinates x,y,z
[60,0,40],// point 3 coordinates x,y,z
[110,0,40]],// point 4 coordinates x,y,z    
3,// number of segments   
[angle,angle],// rev.angle between segments (0-1, 2-3, etc)
odia,//outer diameter of tube   
idia);//inner diameter of tube

	curvedPipe([ 
[-30,0,0],// start point 1 coordinates x,y,z
[30,0,0],// point 2 coordinates x,y,z
[60,0,-40],// point 3 coordinates x,y,z
[110,0,-40]],// point 4 coordinates x,y,z    
3,// number of segments   
[angle,angle],// rev.angle between segments (0-1, 2-3, etc)
odia,//outer diameter of tube   
idia);//inner diameter of tube


	curvedPipe([ 
[-30,0,0],// start point 1 coordinates x,y,z
[30,0,0],// point 2 coordinates x,y,z
[60,-40,0],// point 3 coordinates x,y,z
[110,-40,0]],// point 4 coordinates x,y,z    
3,// number of segments   
[angle,angle],// rev.angle between segments (0-1, 2-3, etc)
odia,//outer diameter of tube   
idia);//inner diameter of tube	
	
	//rotate([0,0,180]) curvedPipe([ [0,0,0],
		//		[100,0,0],
		//		[100,100,0],
		//		[100,100,100],
		//		[0,100,100],
		//		[0,100,0],
		//		[0,0,0],
		//		[50,0,50]
		//	   ],
	    //        7,
		//		[70,30,30,6,50,30],
		//	    10,
		//		8);
}}

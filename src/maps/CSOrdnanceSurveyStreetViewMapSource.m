//
//  RMOpenStreetMapOSMapSource.m
//  MapView
//
//  Created by Neil Edwards on 24/08/2011.
//  Copyright 2011 buffer. All rights reserved.
//

#import "CSOrdnanceSurveyStreetViewMapSource.h"
#import "AppConstants.h"

@implementation CSOrdnanceSurveyStreetViewMapSource


-(NSArray*)tileServeSubDomainPrefixes{
	return @[@"a",@"b",@"c"];
}

-(CGSize)tileSize{
	if (self.isRetinaEnabled) {
		return CGSizeMake(512,512);
	}else{
		return CGSizeMake(256,256);
	}
}


-(int)maxZoom{
	return 19;
}

-(int)minZoom{
	return 1;
}

-(BOOL)isRetinaEnabled{
	return YES;
}

-(BOOL)hasTileServerPrefixes{
	return YES;
}



// for use with new retina tiles
-(NSString*)cacheTileTemplate{
	
	return [NSString stringWithFormat:@"%@/%@/%@",[self tileServerBasePath],[self tileServerName],[self tileServerFileName]];
	
}



// tile server path fragments

-(NSString*)tileServerBasePath{
	if(self.hasTileServerPrefixes){
		return [NSString stringWithFormat:@"http://%@.tile.cyclestreets.net",[self nextTileSubdomainPrefix]];
	}
	return @"http://tile.cyclestreets.net";
}

-(NSString*)tileServerName{
	return @"osopendata";
}

-(NSString*)tileServerFileName{
	if([self isRetinaEnabled]){
		return @"%li/%li/%li@%ix.png";
	}else{
		return @"%li/%li/%li.png";
	}
}



// for use directly with map kit, if - (NSURL *)URLForTilePath:(MKTileOverlayPath)path is implemented this is effectively ignored
- (NSString *)tileTemplate{
	
	if([self isRetinaEnabled]){
		return @"http://tile.cyclestreets.net/osopendata/{z}/{x}/{y}/{s}.png";
	}else{
		return @"http://tile.cyclestreets.net/osopendata/{z}/{x}/{y}.png";
	}
}


-(NSString*) uniqueTilecacheKey
{
	return MAPPING_BASE_OS;
}

-(NSString *)shortName
{
	return @"Open Street Map Ordnance Survey";
}
-(NSString *)longDescription
{
	return @"Open Street Map, the free wiki world map, provides freely usable map data for all parts of the world, under the Creative Commons Attribution-Share Alike 2.0 license.";
}

- (NSString *)shortDescription
{
	return @"Ordnance Survey open data Street View";
}
-(NSString *)shortAttribution
{
	return @" © Ordnance Survey data    ";
}
-(NSString *)longAttribution
{
	return @"Contains Ordnance Survey data (c) Crown copyright and database right 2010";
}

-(NSString*)thumbnailImage{
	return @"OSMapStyle.png";
}

@end

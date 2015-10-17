implement MatrixClient;
include "sys.m";
	sys: Sys;
include "draw.m";

MatrixClient: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

init(nil: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	sys->print("Client started...\n");




}

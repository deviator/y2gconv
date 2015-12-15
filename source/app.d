import std.stdio;

import view;
import model;

void main( string[] args )
{
    runView( args, new Model );
}

void testModel()
{
    auto mdl = new Model;
    mdl.readYTable( "test_table.csv", 10 );
    mdl.writeGTables();
}

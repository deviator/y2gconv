import std.stdio;

import view;
import model;

void main( string[] args )
{
    testModel();
    //runView( args, new Model );
}

void testModel()
{
    import std.range;

    auto mdl = new Model;

    mdl.readYTable( "test_table.csv" );

    mdl.proc();

    mdl.writeGTables( "test_table" );
}

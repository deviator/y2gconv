module view;

import std.string;

import gtk.Widget;
import gtk.Main;
import gtk.Window;
import gtk.Label;
import gtk.Builder;

import model;

enum UI_XML = import( "ui.glade" );

class ViewException : Exception
{
    this( string msg ) @safe pure nothrow
    {
        super( msg );
    }
}

class UI
{
    Builder builder;

    this()
    {
        builder = new Builder;
        if( !builder.addFromString( UI_XML ) )
            throw new ViewException( "cannot create ui" );

        prepare();
    }

    auto obj(T)( string name )
    {
        auto ret = cast(T)builder.getObject( name );
        if( ret is null )
            throw new ViewException( format( "no %s '%s' element", typeid(T).name, name ) );
        return ret;
    }

    void prepare()
    {
        auto w = obj!Window( "mwindow" );
        w.setTitle( "y2g" );
        w.addOnHide( (Widget aux){ Main.quit(); } );
        w.showAll();
    }
}

void runView( string[] args, Model mdl )
{
    Main.init( args );
    new UI;
    Main.run();
}

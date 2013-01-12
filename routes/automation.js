exports.index = function( req, res ) {
  var summary = '';
  var fs=require( 'fs' );
  var inp = fs.createReadStream( '/home/pi/lightwaverf-summary.json' );
  inp.setEncoding( 'utf8' );
  inp.on( 'data', function ( data ) {
    console.log( 'more data: ' + data );
    summary += data;
  } );
  inp.on( 'end', function ( close ) {
    var sys = require( 'sys' );
    var exec = require( 'child_process' ).exec;
    function config ( error, stdout, stderr ) {
      res.render( 'automation', {
        title: 'höme autömatiön',
        ustream: 'offline',
        config: stdout,
        summary: summary || '[]'
      } );
    }
    exec( "/usr/local/bin/lightwaverf-config-json", config );
  } );
};


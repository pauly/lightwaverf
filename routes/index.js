
/*
 * GET home page.
 */

exports.index = function( req, res ) {
  var fs=require( 'fs' );
  var inp = fs.createReadStream( '/home/pi/lightwaverf-summary.json' );
  inp.setEncoding( 'utf8' );
  var summary = '';
  inp.on( 'data', function ( data ) {
    summary += data;
  } );
  inp.on( 'end', function (close) {
    res.render( 'index', {
      title: 'Express',
      ustream: 'offline',
      summary: summary
    } );
  } );
};

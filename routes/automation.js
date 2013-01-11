exports.index = function( req, res ) {
  var summary = '';
  var fs=require( 'fs' );
  var inp = fs.createReadStream( '/home/pi/lightwaverf-summary.json' );
  inp.setEncoding( 'utf8' );
  inp.on( 'data', function ( data ) {
    summary += data;
  } );
  inp.on( 'end', function (close) {
    res.render( 'automation', {
      title: 'home automation',
      ustream: 'offline',
      summary: summary || '[]'
    } );
  } );
};

var sys = require( 'sys' );
var exec = require( 'child_process' ).exec;
var cmd = function ( param ) {
  return '/usr/local/bin/lightwaverf ' + param.room + ' ' + param.device + ' ' + ( param.status || 'on' ) + ' true';
};

exports.index = function( req, res ) {
  var summary = '';
  var fs=require( 'fs' );
  var inp = fs.createReadStream( '/home/pi/lightwaverf-summary.json' );
  inp.setEncoding( 'utf8' );
  inp.on( 'data', function ( data ) {
    summary += data;
  } );
  inp.on( 'end', function ( close ) {
    function config ( err, stdout, stderr ) {
      res.render( 'automation', {
        title: 'höme autömatiön',
        ustream: 'offline',
        user: req.user,
        result: '',
        config: JSON.parse( stdout ),
        summary: summary || '[]'
      } );
    }
    exec( '/usr/local/bin/lightwaverf-config-json', config );
  } );
};

exports.device = function( req, res ) {
  exec( cmd( req.params ), function ( err, stdout, stderr ) {
    res.render( 'automation', {
      title: 'höme autömatiön',
      ustream: 'offline',
      user: req.user,
      result: stdout || stderr || '',
      config: '',
      summary: '[]'
    } );
  } );
};

exports.json = function( req, res ) {
  exec( cmd( req.params ), function ( err, stdout, stderr ) {
    res.json( { result: stdout, error: stderr } );
  } );
};

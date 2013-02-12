var sys = require( 'sys' );
var exec = require( 'child_process' ).exec;
var fs = require( 'fs' );

var cmd = function ( param ) {
  return '/usr/local/bin/lightwaverf ' + param.room + ' ' + param.device + ' ' + ( param.status || 'on' ) + ' true';
};

var ok = function ( user ) {
  console.log( 'ok? user is ' + user.username );
  return user.username === process.env.TWITTER_USER;
}

exports.index = function( req, res ) {
  var summary = '';
  var file = ok( req.user ) ? '/home/pi/lightwaverf-summary.json' : '/home/pi/lightwaverf-summary-dummy.json';
  var inp = fs.createReadStream( file );
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
  console.log( 'automation index' );
  if ( ok( req.user )) {
    return exec( cmd( req.params ), function ( err, stdout, stderr ) {
      res.json( { result: stdout || 'ok', error: stderr } );
    } );
  }
  console.log( 'not ok...' );
  res.json( { result: 'not authorised' } );
};

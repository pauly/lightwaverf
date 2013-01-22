/*
 * Simple node.js utility to read instance energy usage from lightwaverf energy monitor
 * I found the original code here:
 * http://quilowhat.tumblr.com/post/21094672763/energy-monitoring-with-lightwaverf-and-node-js
 * and tweaked it to my requirements... given up using this now, 
 * using the hit-and-run ruby instead of this permanent connection.
var dgram = require( 'dgram' );
var server = dgram.createSocket( 'udp4' );
var winston = require( 'winston' );
winston.add( winston.transports.File, { filename: '/home/pi/lightwaverf.log' } );
server.on( 'message', function ( msg, rinfo ) {
  if ( /W=(\d+),(\d+),(\d+),(\d+)/.exec( msg )) {
    winston.info( { usage: parseInt( RegExp.$1 ), max: parseInt( RegExp.$2 ), today: parseInt( RegExp.$3 ) } );
  }
} );
server.on( 'listening', function ( ) {
  var address = server.address( );
  console.log( 'server listening ' + address.address + ':' + address.port );
} );
server.bind( 9761 );
var client = dgram.createSocket( 'udp4' );
var msgid = 0;
setInterval( function ( client ) {
 var message = new Buffer(( msgid ++ ) + ',@?W', 'ascii' );
 client.send( message, 0, message.length, 9760, '192.168.0.14' );
}, 60000, client );


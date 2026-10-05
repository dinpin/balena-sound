'use strict'

const assert = require('assert')
const { getDefaultRouteInterface } = require('../build/utils')

const routeTable = [
  'Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT',
  'docker0 00000000 010012AC 0003 0 0 20 00000000 0 0 0',
  'wlan0 00000000 0101A8C0 0003 0 0 10 00000000 0 0 0',
  'eth0 00000000 0100A8C0 0000 0 0 1 00000000 0 0 0',
  'eth0 0001A8C0 00000000 0001 0 0 0 00FFFFFF 0 0 0'
].join('\n')

assert.strictEqual(getDefaultRouteInterface(routeTable), 'wlan0')
assert.strictEqual(getDefaultRouteInterface('Iface Destination Gateway Flags RefCnt Use Metric Mask'), null)

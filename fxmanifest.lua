-- FX Information
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
games { 'rdr3', 'gta5' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

version '2.1.1'

shared_scripts {
	'@ox_lib/init.lua',
}

client_scripts {
	'client/compat/init.lua',
	'init.lua',
	'client/*.lua',
	'client/modules/*.lua',
	'client/debug.lua'
}

ui_page 'web/index.html'

files {
	'web/**',
	'web/index.html',
	'client/modules/*.lua',
	'client/framework/*.lua',
	'client/compat/resources/*.lua'
}

provides {
	'ox_target',
	'qtarget'
}

dependency 'ox_lib'

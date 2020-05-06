#!/usr/bin/lua

require("config")
package.path = EXTRACT_WOW_API_DOCS.PathToCode .. "?.lua;" .. package.path


ChatTypeInfo = {}
ChatTypeInfo["SYSTEM"]= { r=255, g=255, b=255, id=1}

DEFAULT_CHAT_FRAME = {}
local function nilChatFrameAddMessage()
	error("Cant use AddMessage right now")
end
DEFAULT_CHAT_FRAME.AddMessage = nilChatFrameAddMessage


local function strsplit(delimiter,text)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( text, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( text, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( text, delimiter, from  )
  end
  table.insert( result, string.sub( text, from  ) )
  return table.unpack(result)
end

function Mixin(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...);
		for k, v in pairs(mixin) do
			object[k] = v;
		end
	end

	return object;
end

function CreateFromMixins(...)
	return Mixin({}, ...)
end


local function readLuaFilesFromToc(tocFile)
	local files = {}
	for line in io.lines(tocFile) do
		line = line:match("^%s*(.-)%s*$")
		if line:match("^[A-Za-z0-9].*lua$") then
			table.insert(files, line:sub(0,-5))
		end
	end
	return files
end

local files = readLuaFilesFromToc(EXTRACT_WOW_API_DOCS.PathToCode .. "Blizzard_APIDocumentation.toc")
for _,file in pairs(files) do
	require(file)
end

local resultFile = nil

local function toHtml(msg)
	local openTags = 0
	local closeTags = 0

	if msg:match("^%s*Part of the .- system%s*$") then
		return ""
	end

	msg = msg:gsub("%|H.-%|h(.-)%|h", "%1")
	msg, openTags = msg:gsub("%|c..(......)", "<span style=\"color: #%1;\">")
	msg, closeTags = msg:gsub("%|r", "</span>")
	while closeTags < openTags do
		msg = msg .. "</span>"
		closeTags = closeTags + 1
	end
	return msg .. "\n"
end

local function printChild(name, link)
	local AddMessage = function(_,msg)
		resultFile:write(toHtml(msg))
	end

	local _, type, name, parentName = strsplit(":",link)
	local apiInfo = APIDocumentation:FindAPIByName(type, name, parentName)
	DEFAULT_CHAT_FRAME.AddMessage=AddMessage
	APIDocumentation:HandleDefaultCommand(apiInfo);
	DEFAULT_CHAT_FRAME.AddMessage=nilChatFrameAddMessage
end

local function findLinks(toCallFunc)
	local sublinks = {}
	local addMessageFunc = function(_,msg)
		for link,name in msg:gmatch("%|H(.-)%|h(.-)%|h") do
			table.insert(sublinks, {name = name, link = link})
		end
	end

	DEFAULT_CHAT_FRAME.AddMessage=addMessageFunc
	toCallFunc()
	DEFAULT_CHAT_FRAME.AddMessage=nilChatFrameAddMessage

	return sublinks
end

local function parseSystem(name, link)
	local _, type, name, parentName = strsplit(":", link)
	local apiInfo = APIDocumentation:FindAPIByName(type, name, parentName);
	local sublinks = findLinks(function() APIDocumentation:HandleDefaultCommand(apiInfo) end)

	for _,entry in ipairs(sublinks) do
		printChild(entry.name, entry.link)
	end
end

local function parseSystems()
	local sublinks = findLinks(function() APIDocumentation:OutputAllSystems() end)
	for _,entry in ipairs(sublinks) do
		parseSystem(entry.name, entry.link)
	end
end

local function writeHtmlStart(file)
	local text = "<!DOCTYPE html>\n"
	text = text .. "<html lang=\"en\"><head><meta charset=\"UTF-8\"><title>WOW LUA API</title>\n"
	text = text .. "<style> body {font-family: monospace; background-color: black; color: white; white-space: pre;} </style></head><body><div>\n"
	file:write(text .. "\n")
end


resultFile = assert(io.open(EXTRACT_WOW_API_DOCS.HtmlFile, "wb"))
writeHtmlStart(resultFile)
parseSystems()
resultFile:write("\n</div></body></html>")
resultFile:close()

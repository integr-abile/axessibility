-- Copyright (C) 2018, 2019, 2020 by 
-- Anna Capietto, Sandro Coriasco, Boris Doubrov, Alexander Koslovski,
-- Tiziana Armano, Nadir Murru, Dragan Ahmetovic, Cristian Bernareggi
--
-- Based on accsupp and tagpdf
--
-- This work consists of the main source files axessibility.dtx and axessibility.lua,
-- and the derived files
--   axessibility.ins, axessibility.sty, axessibility.pdf, README,
--   axessibilityExampleSingleLineT.tex, axessibilityExampleSingleLineA.tex,
--.  axessibilityExampleAlignT.tex, axessibilityExampleAlignA.tex
-- 
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   http://www.latex-project.org/lppl.txt
-- and version 1.3 or later is part of all distributions of LaTeX
-- version 2005/12/01 or later.
--
-- This work has the LPPL maintenance status `maintained'.
-- 
-- The Current Maintainer of this work is 
--               Sandro Coriasco
--


local open_dls = false
local open_double_dls = false

--[[ The function replace_dls_and_double_dls() switches on or off automatic replacement of $$ and $. 
     The boolean argument a (true/false) specifies if the package should do the replacements.
  ]]

function replace_dls_and_double_dls(a) 
	if a and not luatexbase.in_callback("process_input_buffer", "process_input_buffer") then
		luatexbase.add_to_callback("process_input_buffer", replace_chars_callback, "process_input_buffer")
	elseif not a and luatexbase.in_callback("process_input_buffer", "process_input_buffer") then
		luatexbase.remove_from_callback("process_input_buffer", "process_input_buffer")
	end
end

-- the callback that performs the replacement
function replace_chars_callback(a)
	if status.input_ptr == 1 then
		-- variable to save comments if any
		local comment=""
		-- we delete all comments
		a = a:gsub("(\\*)(%%.*)", function(group1, group2)
			-- check,if we have even number of backslash characters
			if #group1 % 2 == 0 then
				comment=group1..group2
				return ""
			end
			return group1..group2
		end)
		
		-- We must replace empty lines by some value, eg % character
		if(open_double_dls or open_dls) and a == "" then
			return "%"
		end

		local replace_happened = false
		a = a:gsub("(\\*)(%$+)", function(group1, group2)
			-- if after \$ we have one or more $,algorithm will not do replacement,so we must be check this situation
			local b = ""
			if #group1 % 2 == 1 and #group2 >1 then
				b="\\$"
				group1 = group1:sub(2)
				group2 = group2:sub(2)
			end
			
			-- if we have even number of backslash characters in front of $$ or $, we do replacement of $$ or $
			if #group1 % 2 == 0 then
				replace_happened = true
				if group2 == "$$" then
					group2 = open_double_dls and "\\]" or "\\["
					open_double_dls = not open_double_dls
				elseif group2 == "$" then
					group2 = open_dls and "\\)" or "\\("
					open_dls = not open_dls
				end
			end
			return group1..b..group2
		end)
		
		--return comments back to the line
		a = a..comment
		-- this might be useful for debug
		--[[ if replace_happened then
			texio.write_nl("the line after replacement is: "..a)
		end]]
		return a
	end
end
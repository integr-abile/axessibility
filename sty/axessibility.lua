pdf.setmajorversion(2)
pdf.setminorversion(0)

local open_dls = false
local open_double_dls = false
-- we use this function to switch on or switch off automatic replacement of $$ and $ 
-- a - the flag (true/false) specifying if the package should do the replacements 
-- b - replace empty lines in formula on some value or not
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
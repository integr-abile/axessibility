pdf.setmajorversion(2)
pdf.setminorversion(0)
	local open_dls = false
local open_double_dls = false
local insert_space_in_empty_strings_if_in_formula = false
-- we use this function to switch on or switch off automatic replacement of $$ and $ 
-- a - the flag (true/false) specifying if the package should do the replacements 
	-- b - replace empty lines in formula on some value or not
function replace_dls_and_double_dls(a,b) 
	if a and not luatexbase.in_callback("process_input_buffer", "process_input_buffer") then
		luatexbase.add_to_callback("process_input_buffer", replace_chars_callback, "process_input_buffer")
	elseif not a and luatexbase.in_callback("process_input_buffer", "process_input_buffer") then
		luatexbase.remove_from_callback("process_input_buffer", "process_input_buffer")
	end
	insert_space_in_empty_strings_if_in_formula=b
end

-- replace $ and $$ on \( \) and \[ \]. 
-- a - line, where we need to do the replacement
-- b - what we must replace
-- c - to what we must replace opening character
-- d - to what we must replace closing character
local function replace_chars(a,b,c,d)
	-- it is easear to compare numbers, if we do not find any match
	local function find(value,index) 
		if not index then
			--set the default value,from which we will start the search.
			index=1
		end
		local result=a:find(value,index)
		return result and result or -1
	end

	-- lua encoding for $
	local d_or_dd = (b == "$$" and "$%$" or "%$") 
	local pattern = "([^\\])"..d_or_dd
	local pattern0 = "([^\\]\\\\)"..d_or_dd
	-- comment (exists problem,if between $ we have more,than three \)
	local pattern_c = "[^\\]%%" 
	--if the user wants to automatically replace empty lines in the formula, we must replace them by some value, eg % character
	if(open_double_dls or open_dls) and insert_space_in_empty_strings_if_in_formula and a == "" then
		return "%"
	end
	local replace_happened = false
	while true do
		--we stop looping, if we have comment before $, $$, \\$ or \\$$ or if we don't have this substrings in the string
		--for optimizing of code,we will save all results of finding of matches in local variables
		local index=find(pattern,index)
		local index0=find(pattern0,index0)
		local index_c=find(pattern_c,index_c)
		if ((index_c <= index or index == -1) and (index_c <= index0 or index0 == -1) and index_c >-1) or (index == -1 and index0 == -1) then
			break
		end
		--[[if we have $ or $$ and $ or $$ closer than \\$ or \\$$ or we don't \\$ or \\$$ and $ or $$ is before 
		 comment or we don't have a comment, we replace $ or $$ on open or closing substring. 
		\\$ and \\$$ processed in the same way]]
		replace_happened = true
		if index >-1 and (index < index_c or index_c == -1) and (index < index0 or index0 == -1) then 
			a = a:gsub(pattern, "%1"..((b == "$$" and open_double_dls or b == "$" and open_dls) and d or c), 1)
		elseif index0 >-1 and (index0 < index_c or index_c == -1) and (index0 < index or index ==-1) then
			a = a:gsub(pattern0, "%1"..((b == "$$" and open_double_dls or b == "$" and open_dls) and d or c), 1)
		end
		if b=="$$" then 
			open_double_dls=not open_double_dls
		elseif b=="$" then 
			open_dls = not open_dls
		end
	end
	if replace_happened then
		texio.write_nl("the line after "..b.." replacement is: "..a)
		replace_happened=false
	end
	return a
end

-- the callback that performs the replacement
function replace_chars_callback(a)
	if status.input_ptr == 1 then
		--[[ to be able to check symbols preceeding $ or % characters, it is easier if they are not the first character in the line
	so, as a workaround we add a space at the beginning of the line, which is removed at the end]]
		a=" "..a
		a = replace_chars(a, "$$", "\\[", "\\]")
		a = replace_chars(a, "$", "\\(", "\\)")
		-- remove the space we inserted before
		a = a:sub(2)
	end
	return a
end

local in_par=false --check,if we open some paragraph or not
function checkpar() --open and close paragraph tags
	if in_par then
		tex.print("\\tagmcend\\tagstructend")
	end
end
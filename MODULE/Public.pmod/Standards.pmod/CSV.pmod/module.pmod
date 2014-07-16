string __version = "0.1";
string __author = "Bertrand LUPART <bertrand.lupart@free.fr>";
array __components = ({ "Public.pmod/Standards.pmod/CSV.pmod/module.pmod" });


/******************************************************************************
			Public.Standards.CSV.CSVIterator
 ******************************************************************************/



/******************************************************************************
				    Helpers 
 ******************************************************************************/


//! Enquote data to be put into a CSV file
//! This means doubling the quoting character: " -> ""
//!
//! @param in
//! The string to quote
//!  Example: Edwin "Buzz" Aldrin
//!
//! @returns
//! The quoted string, ready to be written in a CSV file
//!  Example: Edwin ""Buzz"" Aldrin
string enquote(string in)
{
	return replace(in, ({ "\""}), ({ "\"\""}));
}


//! Dequote data taken from a CSV file
//! This means reducing double quoting character: "" -> "
//!
//! @param in
//! The string to dequote
//!  Example: John ""foo"" Doe
//!
//! @returns
//! The string unquoted, ready to be processed
//!  Example: John "foo" Doe
string dequote(string in)
{
	return replace(in, ({ "\"\"" }) , ({ "\"" }));
}


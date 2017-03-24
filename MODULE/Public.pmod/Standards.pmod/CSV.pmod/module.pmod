/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * Based on Format.CSV Pike module by
 * James Tyson, DogStar SOFTWARE <james@thedogstar.org>.
 * Portions created by the Initial Developer are Copyright (C) 2005
 * the Initial Developer. All Rights Reserved.
 *
 * Author(s):
 *   Bertrand LUPART <bertrand@caudium.net>
 *
 * ***** END LICENSE BLOCK ***** */


string __version = "0.3";
string __author = "Bertrand LUPART <bertrand@caudium.net>";
array __components = ({ "Public.pmod/Standards.pmod/CSV.pmod/module.pmod" });

protected int default_type_detection = 0;


// TODO: PCRE instead of SimpleRegexp? PCRE is faster but optional...
protected object _enquote = Regexp("(,|\"|\n|\r)"); // Matches a string to be quoted

protected object _int = Regexp("^[0-9]+$"); // Matches an int
protected object _float = Regexp("^[0-9]+\\\.[0-9]*$"); // Matches a float
protected object _string = Regexp("^\"*.+\"*$"); // Matches a string



/* Common CSV functions */

//! Enquote data to be put into a CSV file
//! This means doubling the quoting character: " -> ""
//!
//! @param in
//! The string to quote
//!  Example: John "foo" Doe
//!
//! @returns
//! The quoted string, ready to be written in a CSV file
//!  Example: John ""foo"" Doe
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
	return replace (in, ({ "\"\"" }) , ({ "\"" }));
}


//! Determines the "human" type of a string.
//!
//! In CSV, data are stored as strings, but the actual value can be of any type.
//!
//! Example:
//!  "Foo" -> "Foo"
//!  "42" -> 42
//!  "3.14" -> 3.14
//! 
//! @param v
//! The data we want to determine type
//!
//! @returns
//! The actual value, casted as the determined type.
mixed detect_type(mixed v)
{
	// Types can only be determined on a string
	if(!stringp(v))
		return v;

	// MySQL's null
 	if (v == "\\N")
	{
		// Can't think of a good way to suggest NULL that isn't just 0.
		return zero_type; 
  	}

	// Field is an int
	if (_int->match(v))
	{
		return (int)v;
 	}

	// Field is a float
 	if (_float->match(v))
	{
		return (float)v;
	}

	// Field is a string
	if (_string->match(v))
	{
		return v;
	}

	return "";
}



/* Public.Standards.CSV.CSVIterator */

// This CSVIterator takes an Iterator as argument, reads data from it and 
// convert to CSV data on the fly.
// Since that's a generic line Iterator, this can be used for parsing data from
// any source.
protected class CSVIterator
{
	protected int csv_index=-1; // current CSV index
	protected array csv_line = ({ }); // current CSV data

	protected int data_remaining = 1; // Is there still some data to read from the Iterator?

	// line_iterator reads data a line at a time
	object line_iterator;


	/* Iterator API */

	//! @param _input
	//! The file containing the CSV data
	void create(Iterator _iterator)
	{
		line_iterator = _iterator; 

		// Go to the next (first) item
		next();
	}

	// Do we have still some data in our iterator?
  int `!()
	{
		// Nothing's left in the file, no more CSV data
		return !data_remaining;
  }

	// Get next elements from the iterator
	CSVIterator `+=(int steps)
	{
		for(int i=0; i<steps; i++)
		{
			string in = line_iterator->value();

			// If no data from the file iterator
		  if (!in)
			{
				data_remaining=0; // there is no file remaining
				csv_line = 0; // current CSV line is empty
				return this; // exit
			}
	
			parse_csv(in); // parse csv and feed csv_line with them

			// Sanity check loop over the colleted data
			int count = -1;
			foreach(csv_line, mixed v)
			{
				count++;
				if (!sizeof(v))
				{
					csv_line[count] = "" ;
					continue;
				}

				if ((v[0] == '\"') && (v[sizeof(v)-1] == '\"'))
				{
  				// The string is surrounded by speechmarks, so let's
  				// remove them.
  				csv_line[count] = v[1..sizeof(v)-2];
				}
			}

			// Go to the next element
			csv_index++;
			line_iterator->next();
		}

		return this;
	}

	// The current index for the iterator
	int index()
	{
		return csv_index;
	}

	// Increment the iterator
	int next()
	{
		`+=(1);
	}

	// The CSV data for our current index
	int|array value()
	{
		return csv_line;
	}


	/* CSVIterator-specific methods */

	//! Parses a string and tries to find some CSV data in it.
	//! The csv_line array is fed with the data.
	//!
	//! No heuristic is done yet to try to manage malformed CSV data.
	//!
	//! @param in
	//!  The line from the file we want to parse, as a string
	protected void parse_csv(string in)
	{
		// We can't just divide the string on comma, since commas can be quoted
		int quoted = 0; // are we inside a quote sequence?
		int last = 0; // the last char we cared about when feeding result array
		int i = 0; // our current position in the file
		array result = ({ });
		while(sizeof(in[i..i]))
		{
			switch(in[i..i])
			{
				// a " is found, reverse the quote status
				case "\"":
					quoted=!quoted;
					break;
	
				// a , is found
				case ",":
					// if we are not in a quote sequence, split the string
					if(!quoted)
					{
						result += ({ dequote(in[last..(i-1)]) });
						last=i+1;
					}
					break;
			}
	
			// If we're at the end of the line and quoted, we have a CRLF in a field
			// Adding a LF and go to the next the next line
			if(quoted && i==(sizeof(in)-1))
			{
				// FIXME: we're adding \n here, regardless the original data was \n, \r
				// or \r\n
				if(line_iterator->next())
					in+="\n"+line_iterator->value();
				else
				{
					data_remaining=0;
					continue;
				}
			}

			i++;
		}

		// Adding the last part 
		result+=({ dequote(in[last..]) });

		csv_line=result;
	}
}


/* Public.Standards.CSV.CSVDumb */

protected class CSVDumb
{
 	protected int _standards=1;
	protected int do_type_detection=default_type_detection;

  // csv_iterator reads a CSV line at a time
  // a CSV line can be splitted into multiple file lines
	object csv_iterator;

  //! If standards compliant, not all the fields will be enclosed in double
  //! quotes, only thoses containing double quotes, commas and newlines
  //!
  //! @param t
  //!  1 sets the file to be standards compliant
  //!  0 unsets it
  void set_standard_compliance(int t)
  {
    _standards = t;
  }

  //! If standards compliant, not all the fields will be enclosed in double
  //! quotes, only thoses containing double quotes, commas and newlines
  //!
  //! @returns
  //! 1 or 0 wether the file has been set standards compliant or not
  int get_standard_compliance()
  {
    return _standards;
  }

  //! Enable or disable the type detection.
  //! 
  //! @param t
  //!  1 sets the file to detect types
  //!  0 unsets it
  //!
  //! @returns
  //! 1 or 0 wether the file has been set do detect types or not
  void set_type_detection(int t)
  {
    do_type_detection = t;
  }

  //! Check if type detection is enabled or not.
  //!
  //! @returns
  //!  1 or 0 wether the file has been set to detect types or not
  int get_type_detection()
  {
    return do_type_detection;
  }

  //! Read a row
  //!
  //! @returns
  //! The row splitted into an array
  //! 0 if no data
	int|array read_row()
	{
		mixed res = csv_iterator->value();

		// Type detection has not made it into CSVIterator, because it was hell
		// to set/unset type detection on the fly this way
    if(do_type_detection && res)
    {
      foreach(res; mixed indice; mixed value)
      {
        res[indice] = detect_type(value);
      }
    }

		// TODO: this always return an empty line at the end
		// Move the iterators to the next line
		csv_iterator->next();

		return res;
	}
   
}


/* Public.Standards.CSV.String */

class String
{
  inherit CSVDumb;

	void create(string data)
	{
		csv_iterator =
      CSVIterator(global.String.SplitIterator(data||"", ({ 10,13 })));
	}

	protected object _get_iterator()
	{
		return csv_iterator;
	}

	protected string _sprintf(mixed ... args)
	{
		return "Public.Standards.CSV.String";
	}
}



/* Public.Standards.CSV.FILE */

class FILE
{
  inherit CSVDumb;
	inherit Stdio.FILE : file;

  void create(mixed ... args)
  {
    file::create(@args);

    csv_iterator = CSVIterator(this_object()->line_iterator(1));
  }

	//! Write a row
	//!
	//! @param row
	//!	The data to write
	//!
	//! @returns
	//! The number of bytes written 
	int write_row(mixed... row)
	{
		if (arrayp(row) && (sizeof(row) == 1) && arrayp(row[0]))
			row = row[0];

	  array result = ({});
	  foreach(row, mixed r)
		{
			string v = (string)r;

			if (_standards)
			{
				if (_enquote->match(v))
					result += ({ sprintf("\"%s\"", enquote(v)) });
				else
					result += ({ enquote(v) });
			}
			else
				result += ({ sprintf("\"%s\"", enquote(v)) });
		}

	  return ::write((result * ",") + "\n");
	}

	protected object _get_iterator()
	{
    return csv_iterator;
	}

	protected string _sprintf(mixed... args)
	{
		return replace(::_sprintf(@args), "Stdio.FILE", "Public.Standards.CSV.FILE");
	}
}



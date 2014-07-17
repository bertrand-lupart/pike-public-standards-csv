/*
 *
 * Author(s):
 *   Bertrand LUPART <bertrand.lupart@free.fr>
 */

string __version = "0.1";
string __author = "Bertrand LUPART <bertrand.lupart@free.fr>";
array __components = ({ "Public.pmod/Standards.pmod/CSV.pmod/module.pmod" });



/******************************************************************************
                        Public.Standards.CSV.CSVIterator
 ******************************************************************************/

// This CSVIterator takes an Iterator as argument, reads data from it and 
// convert to CSV data on the fly.
// Since that's a generic line Iterator, this can be used for parsing data from
// any source.
class CSVIterator
{
  static int csv_index=-1; // current CSV index
  static array csv_line = ({ }); // current CSV data

  // Is there still some data to read from the Iterator?
  static int data_remaining = 1;

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

  // Do we have still some data in our Iterator?
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
        data_remaining=0; // there is no data remaining
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
  //! No heuristic is done to try to manage malformed CSV data.
  //!
  //! @param in
  //!  The line from the file we want to parse, as a string
  static void parse_csv(string in)
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
        {
          in+="\n"+line_iterator->value();
        }
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



/******************************************************************************
                           Public.Standards.CSV.FILE
 ******************************************************************************/

class FILE
{
  inherit Stdio.FILE;

  static int _standards=1; // Do we want to be standards compliant for output?

  static object _enquote = Regexp("(,|\"|\n|\r)"); // Matches a string to be quoted

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


  //! Write a row
  //!
  //! @param row
  //! The data to write
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

  //! Read a row
  //!
  //! @returns
  //! The row splitted into an array
  //! 0 if no data
  int|array read_row()
  {
    // We have to instanciate the CSVIterator the first time
    // TODO: shouldn't it be in create()?
    if(!objectp(csv_iterator))
    {
      csv_iterator = CSVIterator(this_object()->line_iterator(1));
    }

    mixed res = csv_iterator->value();

    // Move the iterators to the next line
    csv_iterator->next();

    return res;
  }

  static object _get_iterator()
  {
    return  CSVIterator(this_object()->line_iterator(1));
  }

  static string _sprintf(mixed... args)
  {
    return
      replace(::_sprintf(@args), "Stdio.FILE", "Public.Standards.CSV.FILE");
  }

}




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

------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2018-2019, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with GNATCOLL.JSON;

package Tester.Macros is

   procedure Expand
     (Test : in out GNATCOLL.JSON.JSON_Value;
      Path : String);
   --  Expand macros in given JSON test
   --
   --  Currently only one macro is supported:
   --  * ${TD} - expands with test directory, a directory of .json file
   --
   --  * $URI{x} - rewrite as "file:///path", treat x as relative to test
   --  directory if x isn't an absolute path

end Tester.Macros;

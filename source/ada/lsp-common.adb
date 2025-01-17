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

with Ada.Exceptions;           use Ada.Exceptions;
with GNAT.Strings;
with GNAT.Traceback.Symbolic;  use GNAT.Traceback.Symbolic;
with GNATCOLL.Utils;           use GNATCOLL.Utils;

with Langkit_Support.Text;
with Libadalang.Common;        use Libadalang.Common;

package body LSP.Common is

   ---------
   -- Log --
   ---------

   procedure Log
     (Trace   : GNATCOLL.Traces.Trace_Handle;
      E       : Ada.Exceptions.Exception_Occurrence;
      Message : String := "") is
   begin
      if Message /= "" then
         Trace.Trace (Message);
      end if;

      Trace.Trace (Exception_Name (E) & ": " & Exception_Message (E)
                   & ASCII.LF & Symbolic_Traceback (E));
   end Log;

   --------------------
   -- Get_Hover_Text --
   --------------------

   function Get_Hover_Text (Node : Ada_Node'Class) return LSP_String
   is
      Text   : constant String := Langkit_Support.Text.To_UTF8
        (Node.Text);
      Lines  : GNAT.Strings.String_List_Access := Split
        (Text,
         On               => ASCII.LF,
         Omit_Empty_Lines => True);

      Result : LSP_String;

      procedure Get_Basic_Decl_Hover_Text;
      --  Create the hover text for for basic declarations

      procedure Get_Subp_Spec_Hover_Text;
      --  Create the hover text for subprogram declarations

      procedure Get_Package_Decl_Hover_Text;
      --  Create the hover text  for package declarations

      procedure Get_Loop_Var_Hover_Text;
      --  Create the hover text for loop variable declarations

      -------------------------------
      -- Get_Basic_Decl_Hover_Text --
      -------------------------------

      procedure Get_Basic_Decl_Hover_Text is
      begin
         case Node.Kind is
            when Ada_Package_Body =>

               --  This means that user is hovering on the package declaration
               --  itself: in this case, return a empty response since all the
               --  relevant information is already visible to the user.
               return;

            when Ada_For_Loop_Var_Decl =>

               --  Return the first line of the enclosing for loop when
               --  hovering a for loop variable declaration.
               declare
                  Parent_Text : constant String := Langkit_Support.Text.To_UTF8
                    (As_For_Loop_Var_Decl (Node).P_Semantic_Parent.Text);
                  End_Idx     : Natural := Parent_Text'First;
               begin
                  Skip_To_String
                    (Str       => Parent_Text,
                     Index     => End_Idx,
                     Substring => "loop");

                  Result := To_LSP_String
                    (Parent_Text (Parent_Text'First .. End_Idx + 4));
                  return;
               end;

            when others =>
               declare
                  Idx : Integer;
               begin
                  --  Return an empty hover text if there is no text for this
                  --  delclaration (only for safety).
                  if Text = "" then
                     return;
                  end if;

                  --  If it's a single-line declaration, replace all the
                  --  series of whitespaces by only one blankspace. If it's
                  --  a multi-line declaration, remove only the unneeded
                  --  indentation whitespaces.

                  if Lines'Length = 1 then
                     declare
                        Res_Idx : Integer := Text'First;
                        Tmp     : String (Text'First .. Text'Last);
                     begin
                        Idx := Text'First;

                        while Idx <= Text'Last loop
                           Skip_Blanks (Text, Idx);

                           while Idx <= Text'Last
                             and then not Is_Whitespace (Text (Idx))
                           loop
                              Tmp (Res_Idx) := Text (Idx);
                              Idx := Idx + 1;
                              Res_Idx := Res_Idx + 1;
                           end loop;

                           if Res_Idx < Tmp'Last then
                              Tmp (Res_Idx) := ' ';
                              Res_Idx := Res_Idx + 1;
                           end if;
                        end loop;

                        if Res_Idx > Text'First then
                           Result := To_LSP_String
                             (Tmp (Tmp'First .. Res_Idx - 1));
                        end if;
                     end;
                  else
                     declare
                        Blanks_Count_Per_Line : array
                          (Lines'First + 1 .. Lines'Last) of Natural;
                        Indent_Blanks_Count   : Natural := Natural'Last;
                        Start_Idx             : Integer;
                     begin
                        Result := To_LSP_String (Lines (Lines'First).all);

                        --  Count the blankpaces per line and track how many
                        --  blankspaces we should remove on each line by
                        --  finding the common identation blankspaces.

                        for J in Lines'First + 1 .. Lines'Last loop
                           Idx := Lines (J)'First;
                           Skip_Blanks (Lines (J).all, Idx);

                           Blanks_Count_Per_Line (J) := Idx - Lines (J)'First;
                           Indent_Blanks_Count := Natural'Min
                             (Indent_Blanks_Count,
                              Blanks_Count_Per_Line (J));
                        end loop;

                        for J in Lines'First + 1 .. Lines'Last loop
                           Start_Idx := Lines (J)'First + Indent_Blanks_Count;
                           Result := Result & To_LSP_String
                             (ASCII.LF
                              & Lines (J).all (Start_Idx .. Lines (J)'Last));
                        end loop;
                     end;
                  end if;

                  GNAT.Strings.Free (Lines);
               end;
         end case;
      end Get_Basic_Decl_Hover_Text;

      ------------------------------
      -- Get_Subp_Spec_Hover_Text --
      ------------------------------

      procedure Get_Subp_Spec_Hover_Text is
         Idx : Integer;
      begin
         --  For single-line subprogram specifications, we display the
         --  associated text directly.
         --  For multi-line ones, remove the identation blankspaces to replace
         --  them by a fixed number of blankspaces.

         if Lines'Length = 1 then
            Result := To_LSP_String (Text);
         else
            Result := To_LSP_String (Lines (Lines'First).all);

            for J in Lines'First + 1 .. Lines'Last loop
               Idx := Lines (J)'First;
               Skip_Blanks (Lines (J).all, Idx);

               Result := Result
                 & To_LSP_String
                 (ASCII.LF
                  & (if Lines (J).all (Idx) = '(' then "  " else "   ")
                  & Lines (J).all (Idx .. Lines (J).all'Last));
            end loop;
         end if;

         GNAT.Strings.Free (Lines);
      end Get_Subp_Spec_Hover_Text;

      ---------------------------------
      -- Get_Package_Decl_Hover_Text --
      ---------------------------------

      procedure Get_Package_Decl_Hover_Text is
         Generic_Params : LSP_String;
         End_Idx        : Natural := Text'First;
      begin
         --  Return the first line of the package declaration and its
         --  generic parameters if any.
         Skip_To_String
           (Str       => Text,
            Index     => End_Idx,
            Substring => " is");

         if Node.Parent /= No_Ada_Node
           and then Node.Parent.Kind in Ada_Generic_Decl
         then
            Generic_Params := To_LSP_String
              (Langkit_Support.Text.To_UTF8
                 (As_Generic_Decl (Node.Parent).F_Formal_Part.Text)
               & ASCII.LF);
         end if;

         Result := Generic_Params
           & To_LSP_String (Text (Text'First .. End_Idx));
      end Get_Package_Decl_Hover_Text;

      -----------------------------
      -- Get_Loop_Var_Hover_Text --
      -----------------------------

      procedure Get_Loop_Var_Hover_Text is
         Parent_Text : constant String := Langkit_Support.Text.To_UTF8
           (As_For_Loop_Var_Decl (Node).P_Semantic_Parent.Text);
         End_Idx     : Natural := Parent_Text'First;
      begin
         --  Return the first line of the enclosing for loop when
         --  hovering a for loop variable declaration.

         Skip_To_String
           (Str       => Parent_Text,
            Index     => End_Idx,
            Substring => "loop");

         Result := To_LSP_String
           (Parent_Text (Parent_Text'First .. End_Idx + 4));
      end Get_Loop_Var_Hover_Text;

   begin
      case Node.Kind is
         when Ada_Package_Body =>

            --  This means that the user is hovering on the package declaration
            --  itself: in this case, return a empty response since all the
            --  relevant information is already visible to the user.
            return Empty_LSP_String;

         when Ada_Base_Package_Decl =>
            Get_Package_Decl_Hover_Text;

         when Ada_For_Loop_Var_Decl =>
            Get_Loop_Var_Hover_Text;

         when Ada_Base_Subp_Spec =>
            Get_Subp_Spec_Hover_Text;

         when others =>
            Get_Basic_Decl_Hover_Text;
      end case;

      return Result;
   end Get_Hover_Text;

end LSP.Common;

# App::Pods2Site
---
**NOTE: This is the master branch of this repo and should not contain anything else than this document.** Active branches are listed below - checkout the relevant one before doing any work!  

### About
App::Pods2Site is a Perl module @@TBD@@

#### Versioning
The module uses the apparently most prevalent model for module versioning: a floating point value, where the two parts are major and minor respectively, where _major_ increases **may** contain backwards incompatible changes, but _minor_ **must not** do so. There is little other implied meaning in the numbers and visible releases might not always have consecutive numbers (e.g. due to problems during late found problems or repo management issues).

It is expressed as a _string_ (for the benefit of version scanners and to avoid dropping zeroes at the end) and next evaled into a number. The decimal part is always at least 3 digits long, but can be longer for developer only releases, expressed with an underscore and then another three digit number.  

The minor number will use even numbers for end-user releases and odd for developer only releases.  

Examples:
  * 1.000  
    The first end-user release  
  * 1.001_042  
    A developer release working up to release 1.002  
  * 2.012

#### Repo branching/tagging structure
The branching structure is intended to follow the version structure closely. The starting branch is named simply '**x**', where the 'x' signifies that only major releases of '1', '2', '3'...etc may be done here (in practice the releases will be tagged as '1.000' and so on). This branch has a separate commit graph from master and they should not be confused or merged.

Once the tagging has been made, a new branch will be cut away, named after the major branch, e.g. '**1.xxx**'. The 'xxx' again stands for a number, now in the minor series such that only minor releases in the '1' major series may be done here, e.g. '1.002', '1.004' etc. Also '000' developer releases may be done here, tagged for example '1.001_000', which will result in a '**1.001_xxx**' branch, where further developer releases are tagged until finished. A developer release branch is not required, commits may happen directly on '1.xxx' until complete.

When a sub branch is completed it will be merged back to it's parent, e.g. the '1.001_xxx' branch is eventually deemed ready, and is thus merged back to '1.xxx' for eventual release as '1.002'. The same holds true for '1.xxx' that it will eventually be merged back to 'x'.

### Releases
  * N/A

### Active branches
  * **master**  
    For maintenance of this document only.
  * **x**  
    For work aimed at v1.000

#### LICENSE AND COPYRIGHT

Copyright (C) 2017 Kenneth Olwing

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

http://www.perlfoundation.org/artistic_license_2_0

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

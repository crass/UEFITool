/* uinttypes.h

Copyright (c) 2021, Nikolaj Schlej. All rights reserved.
This program and the accompanying materials
are licensed and made available under the terms and conditions of the BSD License
which accompanies this distribution.  The full text of the license may be found at
http://opensource.org/licenses/bsd-license.php

THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
*/

#ifndef UINTTYPES_H
#define UINTTYPES_H

// A workaround for compilers not supporting c++11 and c11
// for using PRIX64.
#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#if defined(__clang__) || defined(__GNUC__)
#define ATTRIBUTE_FORMAT_(t,f,a) __attribute__((format(t, f, a)))
#else
#define ATTRIBUTE_FORMAT_(t,f,a)
#endif

#endif // UINTTYPES_H

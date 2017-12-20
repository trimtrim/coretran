module m_idDynamicArray
!! Class that act as stacks, queues, and priority queues.
!! These classes use dynamically allocated contiguous blocks of memory to store a list of numbers.
!! The queues can be sorted to become priority queues and use binary searches to quickly insert new numbers.
!! If the allocated memory is filled, the available space is doubled.
!! Memory is only reallocated to a smaller size, if the utilization is a quarter of that allocated.
!!
!!```fortran
!!program dynamicArray_test
!!use variableKind, only: i32
!!use m_dynamicArray, only: idDynamicArray
!!
!!implicit none
!!
!!type(idDynamicArray) :: idda, idda2
!!integer(i32) :: ia
!!
!!idda = idDynamicArray(10) ! array is empty but with memory allocated for 10 numbers
!!call idda%insert(1, 10.d0) ! array is [10.d0]
!!call idda%insert(1, 20.d0) ! array is [20.d0, 10.d0]
!!call idda%prepend(30.d0) ! array is [30.d0, 20.d0, 10.d0]
!!call idda%append(40.d0) ! array is [30.d0, 20.d0, 10.d0, 40.d0]
!!call idda%remove(2) ! array is [30.d0, 10.d0, 40.d0]
!!call idda%tighten() ! array memory changed to match, i.e. 3.
!!idda2 = idda ! non-pointer copy of dynamic array
!!call idda%deallocate() ! deallocate memory in the dynamic array
!!call idda2%deallocate() ! deallocate memory in the dynamic array
!!idda = idDynamicArray(3) ! Initialized 3 space dynamic array
!!call idda%insertSorted(20.d0) ! Sorted insertion
!!call idda%insertSorted(30.d0) ! Sorted insertion [20.d0, 30.d0]
!!call idda%insertSorted(10.d0) ! Sorted insertion [10.d0, 20.d0, 30.d0]
!!ia = idda%locationOf(20.d0) ! Only use locat
!!call test%test(ia == 2, 'idDynamicArray%locationOf')
!!call idda%insertSortedUnique(10.d0)
!!call test%test(all(idda%values==[10.d0, 20.d0, 30.d0]), 'idDynamicArray%insertSortedUnique')
!!call idda%insertSortedUnique(15.d0)
!!call test%test(all(idda%values==[10.d0, 15.d0, 20.d0, 30.d0]), 'idDynamicArray%insertSortedUnique')
!!call test%test(size(idda%values) == 6, 'idDynamicArray%insert')
!!end program
!!```

use variableKind, only: i32, i64
use m_allocate, only: allocate
use m_searching, only: binarySearch, intervalSearch
use m_deallocate, only: deallocate
use m_errors, only: eMsg
use m_reallocate, only: reallocate
use m_sort, only: sort
use m_strings, only: str

implicit none

private

public :: idDynamicArray

type :: idDynamicArray
  !! Class that act as stacks, queues, and priority queues. See [[m_idDynamicArray]] for more information on how to use this class.
  integer(i32) :: N
    !! Current size of the array
  integer(i64), allocatable :: values(:)
    !! Memory for values, can be larger than N
  logical :: sorted = .false.
    !! Keep track of whether the array is sorted for potential speed increases
  logical :: fixed = .false.
    !! Don't allow the memory to change after initial instantiation.
contains
  procedure, public :: append => append_idDynamicArray
    !! idDynamicArray%append() - Append a value to the end of the dynamic array.  Will change a sorted dynamic array to unsorted.
  procedure, public :: deallocate => deallocate_idDynamicArray
    !! idDynamicArray%deallocate() - Deallocate a dynamic array.
  procedure, public :: insertAt => insertAt_idDynamicArray
    !! idDynamicArray%insertAt() - Insert a value at a given index.
  procedure, public :: insertSorted => insertSorted_idDynamicArray
    !! idDynamicArray%insertSorted() - Insert a value into a sorted dynamic array.
  procedure, public :: insertSortedUnique => insertSortedUnique_idDynamicArray
    !! idDynamicArray%insertSortedUnique() - Inserts only unique numbers into a dynamic array.
  procedure, public :: locationOf => locationOf_idDynamicArray
    !! idDynamicArray%locationOf() - Get the location of a value in a sorted dynamic array.
  procedure, public :: prepend => prepend_idDynamicArray
    !! idDynamicArray%prepend() - Prepend a value to the start of the dynamic array. Only for unsorted dynamic arrays
  procedure, public :: reallocate => reallocate_idDynamicArray
    !! idDynamicArray%reallocate() - Create new contiguous memory to match the needs of the expanding or shrinking array.
  procedure, public :: remove => remove_idDynamicArray
    !! idDynamicArray%remove() - Remove an element from the array.
  procedure, public :: tighten => tighten_idDynamicArray
    !! idDynamicArray%tighten() - Removes excess buffer memory and trims it to the current length.
end type


interface idDynamicArray
  procedure :: init_idDynamicArray_i1, init_idDynamicArray_d1D
end interface

interface assignment(=)
  procedure :: copy_idDynamicArray
end interface

contains

  !====================================================================!
  subroutine append_idDynamicArray(this,val)
    !! Overloaded type bound procedure idDynamicArray%append()
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i64) :: val
    !! Value to append.
  if (this%fixed) call eMsg('idDynamicArray%append: Cannot use append with fixed array.')
  call this%insertAt(this%N + 1, val) ! Append at last location
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine copy_idDynamicArray(new,this)
    !! Overloaded assignment of equals.  new = this
  !====================================================================!
  class(idDynamicArray), intent(in) :: this
    !! Class to copy.
  type(idDynamicArray), intent(out) :: new
    !! Copy of this.
  call allocate(new%values, size(this%values))
  new%N = this%N
  new%values = this%values
  new%sorted = this%sorted
  new%fixed = this%fixed
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine deallocate_idDynamicArray(this)
    !! Overloaded type bound procedure idDynamicArray%deallocate()
  !====================================================================!
  class(idDynamicArray) :: this
  call deallocate(this%values)
  this%N = 0
  this%sorted = .false.
  end subroutine
  !====================================================================!
  !====================================================================!
  function init_idDynamicArray_i1(M, sorted, fixed) result(this)
    !! Overloaded by interface idDynamicArray()
  !====================================================================!
  integer(i32), intent(in), optional :: M
    !! Amount of memory to allocate.
  logical, intent(in), optional :: sorted
    !! Maintain a sorted array.
  logical, intent(in), optional :: fixed
    !! Maintain a fixed size array.
  type(idDynamicArray) :: this
    !! Return type.

  integer(i32) :: M_
  M_ = 1
  if (present(M)) then
    if (M < 1) call eMsg('M must be > 0')
    M_ = M
  endif
  call allocate(this%values, M_)
  this%N = 0

  this%sorted = .false.
  if (present(sorted)) this%sorted = sorted
  this%fixed = .false.
  if (present(fixed)) this%fixed = fixed
  end function
  !====================================================================!
  !====================================================================!
  function init_idDynamicArray_d1D(values, M, sorted, fixed) result(this)
    !! Overloaded by interface idDynamicArray()
  !====================================================================!
  integer(i64), intent(in) :: values(:)
      !! Set of values to initialize with.
  integer(i32), intent(in), optional :: M
    !! Amount of memory to allocate.
  logical, intent(in), optional :: sorted
    !! Maintain a sorted array.
  logical, intent(in), optional :: fixed
    !! Maintain a fixed size array.
  type(idDynamicArray) :: this
    !! Return type

  if (present(M)) then
    if (M < size(values)) call eMsg('M must be >= size(values)')
    call allocate(this%values, M)
  else
    call allocate(this%values, size(values))
  endif

  this%N = size(values)

  this%sorted = .false.
  if (present(sorted)) this%sorted = sorted
  if (this%sorted) then
      this%values(1:this%N) = values
      call sort(this%values(1:this%N))
  else
      this%values(1:this%N) = values
  endif
  this%fixed = .false.
  if (present(fixed)) this%fixed = fixed
  end function
  !====================================================================!
  !====================================================================!
  subroutine insertAt_idDynamicArray(this,i,val)
    !! Overloaded type bound procedure idDynamicArray%insertAt()
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i32) :: i
    !! Insert value at this location.
  integer(i64) :: val
    !! Insert this value.
  integer :: j, N
  if (i < 1 .or. i > this%N + 1) call Emsg('idDynamicArray%insert: 1 <= i <= '//str(this%N + 1))

  N = size(this%values)

  if (this%fixed) then
    if (i > N) call Emsg('idDynamicArray%insert: For fixed array, 1 <= i <= '//str(N))

    if (this%N < N) this%N = this%N + 1

    do j = this%N, i+1, -1
      this%values(j) = this%values(j-1)
    enddo
  else
    ! Expand the vector if needed
    if (N < this%N + 1) call this%reallocate(2 * N)
    do j = this%N + 1, i + 1, -1
      this%values(j) = this%values(j-1)
    enddo
    this%N = this%N + 1
  endif

  this%values(i) = val
  this%sorted = .false.
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine insertSorted_idDynamicArray(this,val)
    !! Overloaded type bound procedure idDynamicArray%insertSorted()
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i64) :: val
    !! Insert this value.
  integer(i32) :: iSearch(3) ! location and interval of new value
  if (.not. this%sorted) call eMsg('idDynamicArray%insertSorted: Cannot use insertSorted with unsorted dynamic array')
  iSearch=intervalSearch(this%values, val, 1, this%N)
  call this%insertAt(iSearch(3), val)
  this%sorted = .true.
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine insertSortedUnique_idDynamicArray(this,val)
    !! Overloaded type bound procedure idDynamicArray%insertSortedUnique()
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i64) :: val
    !! Insert this value.
  integer(i32) :: iSearch(3) ! location and interval of new value
  if (.not. this%sorted) call eMsg('idDynamicArray%insertSortedUnique: Cannot use insertSortedUnique with unsorted dynamic array')
  iSearch=intervalSearch(this%values, val, 1, this%N)
  if (iSearch(1) == -1) then
    call this%insertAt(iSearch(3), val)
    this%sorted = .true.
  endif
  end subroutine
  !====================================================================!
  !====================================================================!
  function locationOf_idDynamicArray(this, val) result(i)
    !! Overloaded type bound procedure idDynamicArray%locationOf().
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i64) :: val
    !! Get the location of this value
  integer(i32) :: i
    !! Location of value
  if (.not. this%sorted) call eMsg('idDynamicArray%locationOf: Cannot use locationOf with unsorted dynamic array')
  i = binarySearch(this%values, val, 1, this%N)
  end function
  !====================================================================!
  !====================================================================!
  subroutine prepend_idDynamicArray(this,val)
    !! Overloaded type bound procedure idDynamicArray%prepend()
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i64) :: val
    !! Value to prepend.
  if (this%fixed) call eMsg('idDynamicArray%prepend: Cannot use prepend with fixed array.')
  call this%insertAt(1, val) ! Prepend at first location
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine reallocate_idDynamicArray(this, M)
    !! Overloaded type bound procedure idDynamicArray%reallocate().
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i32) :: M
    !! Reallocate memory to this size.
  call reallocate(this%values, M)
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine remove_idDynamicArray(this, i)
    !! Overloaded type bound procedure idDynamicArray%remove().
  !====================================================================!
  class(idDynamicArray) :: this
  integer(i32) :: i
    !! Remove the value at this location.
  integer(i32) :: j
  if (i < 1 .or. i > this%N) call Emsg('idDynamic%remove: 1 <= i <= '//str(this%N))
  do j = i, this%N - 1
    this%values(j) = this%values(j + 1)
  enddo
  this%N = this%N - 1
  if (.not. this%fixed) then
    if (this%N < size(this%values)/4) call this%reallocate(this%N)
  endif
  end subroutine
  !====================================================================!
  !====================================================================!
  subroutine tighten_idDynamicArray(this)
    !! Overloaded type bound procedure idDynamicArray%tighten().
  !====================================================================!
  class(idDynamicArray) :: this
  if (this%fixed) call eMsg('idDynamicArray%tighten: Cannot use tighten with fixed array.')
  call this%reallocate(this%N)
  end subroutine
  !====================================================================!
end module

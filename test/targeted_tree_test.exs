defmodule PropCheck.Test.TargetTreeTest do
  @moduledoc """
  This is the binary tree example for Targeted Properties of Fred Hebert's book "
  Property Based Testing"
  """
  use PropCheck
  use ExUnit.Case

  require Logger

  @doc "Make a tree from a list"
  def to_tree(l), do: Enum.reduce(l,:undefined, &insert/2)

  @doc "Insert into a tree, the empty tree is `:undefined`"
  def insert(n, node = {:node, m, _l, _r}) when n == m, do: node
  def insert(n, {:node, m, l, r}) when n < m, do: {:node, m, insert(n, l), r}
  def insert(n, {:node, m, l, r}) when n > m, do: {:node, m, l, insert(n, r)}
  def insert(n, leaf = {:leaf, m}) when n == m, do: leaf
  def insert(n, leaf = {:leaf, m}) when n < m, do: {:node, n, :undefined, leaf}
  def insert(n, leaf = {:leaf, m}) when n > m, do: {:node, n, leaf, :undefined}
  def insert(n, :undefined), do: {:leaf, n}

  @doc "Calculate a kind of height of the left and and right subtree"
  def sides({:node, _, left, right}) do
    {ll, lr} = sides(left)
    {rl, rr} = sides(right)
    {count_inner(left) + ll + lr, count_inner(right) + rl + rr}
  end
  def sides(_), do: {0,0}
  def count_inner({:node, _, _, _}), do: 1
  def count_inner(_), do: 0

  #####################################################################################

  ## Generator for trees
  def tree() do
    let l <- non_empty(list(integer())) do
      to_tree(l)
    end
  end

  property "A left-heavy tree" do
    forall_targeted t <- tree() do
      weight = sides(t)
      {left, right} = weight
      IO.write(" #{inspect weight}")
      # ensure that the left tree is larger than the right one
      maximize(left-right)
      true # this property holds always
    end
  end

  property "A simple tree", [numtests: 1_000] do
    forall t <- tree() do
      weight = sides(t)
      IO.write(" #{inspect weight}")
      true # this property holds always
    end
  end

  #####################################################################################
  # define our own neighborhood function achive even more left-heavy trees

  @doc "Returns the generator function for next value depending on the temperature"
  def next_tree() do
    fn old_tree, {_, temperature} ->
      let n <- integer() do
        scaled_value = trunc(n * temperature * 100)
        insert(scaled_value, old_tree)
      end
    end
  end

  property "A very left-heavy tree with neighborhood function"  do
    forall_targeted t <- user_nf(tree(), next_tree()) do
      weight = sides(t)
      {left, right} = weight
      IO.write(" #{inspect weight}")
      # ensure that the left tree is larger than the right one
      maximize(left-right)
      true # this property holds always
    end
  end

  #####################################################################################
  # Combine regular properties with user-defined neighborhood-fucntion and
  # a search strategy inside.

  property "Tree search", [:verbose, search_steps: 100]  do
    forall l <- list(integer()) do
      not_exists t <- user_nf(
          # trick: wrap the list value l into the let to construct the
          # required generator for user_nf
          ( let x <- l, do: to_tree(x) ),
          next_tree()) do
        weight = sides(t)
        {left, right} = weight
        IO.write(" #{inspect weight}")
        # ensure that the left tree is larger than the right one
        maximize(left-right)
        false # guarantees a full search for exists
      end
    end
  end


end

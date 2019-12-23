defmodule NicIo do
  # r/w ops work in multiples of two octets, but just maintain flat queue of octet values
  defstruct [rx_q: [], tx_buf: []]
end

defmodule Cat6Nics.WorldAffairs do
  @moduledoc """
    maintain state _between_ callbacks from IntCode[Boost] NIC processes
  """

  # from problem definition
  @eof (-1)

  # supervisor trees not required in this scenario
  # use Agent

  @spec initialize(Keyword.t()) :: pid
  def initialize(initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @spec handle_input_request(integer) :: integer
  def handle_input_request(nic_idx) do
    Agent.get_and_update(
      __MODULE__,
      fn state ->
        all_nic_io = Keyword.fetch!(state, :all_nic_io)

        nic_io = all_nic_io |> Map.fetch!(nic_idx)

        case nic_io.rx_q do
          [] ->
            {@eof, state}

          [val | further_vals] -> 
            # XXX
            if val == nic_idx, do: IO.inspect(nic_idx, label: "\nbooting")

            new_nic_io = %{nic_io | rx_q: further_vals}
            new_all_nic_io = Map.put(all_nic_io, nic_idx, new_nic_io)
            new_state = Keyword.merge(state, [all_nic_io: new_all_nic_io])
            {val, new_state}
        end
      end
    )
  end

  @spec handle_output_request(integer, integer) :: :ok
  def handle_output_request(nic_idx, value) do
    Agent.update(
      __MODULE__,
      fn state ->
        all_nic_io = Keyword.fetch!(state, :all_nic_io)

        nic_io = all_nic_io |> Map.fetch!(nic_idx)

        new_all_nic_io =
          case nic_io.tx_buf do
            tx_buf when length(tx_buf) < 2 ->
              # v.short list, so grudgingly tolerate list concentation
              new_nic_io = %{nic_io | tx_buf: nic_io.tx_buf ++ [value]}
              Map.put(all_nic_io, nic_idx, new_nic_io)

            [255, prev_value] ->
              # XXX return result value properly
              value
              |> IO.inspect(label: "\nTX(addr=255,prev=#{prev_value}")

            [addr, prev_value] ->
              # update receiver
              nic_io_rx = all_nic_io |> Map.fetch!(addr)

              new_nic_io_rx = %{nic_io_rx | rx_q: nic_io_rx.rx_q ++ [prev_value, value]}
              new_all_nic_io_rx = Map.put(all_nic_io, addr, new_nic_io_rx)

              # clear transmitter (w/o losing receiver updates)
              new_nic_io_tx = %{nic_io | tx_buf: []}
              Map.put(new_all_nic_io_rx, nic_idx, new_nic_io_tx)
          end

        Keyword.merge(state, [all_nic_io: new_all_nic_io])
      end
    )

    :ok
  end
end

defmodule Cat6Nics do
  @moduledoc """
  simulate 50 NICs with RX/TX buffers and non-blocking I/O
  """

  @num_nics 50

  alias Cat6Nics.WorldAffairs

  @doc """
  (part 1)
  """
  @spec execute([integer]) :: integer
  def execute(firmware) do
    # "when each computer boots up, it will request its network address via a single input instruction"
    init_all_nic_io =
      0..(@num_nics - 1)
      |> Enum.map(fn i -> {i, %NicIo{rx_q: [i], tx_buf: []}} end)
      |> Enum.into(%{})

    {:ok, _pid} = WorldAffairs.initialize(all_nic_io: init_all_nic_io)

    all_tasks =
      0..(@num_nics - 1)
      |> Enum.map(
        fn i ->
          run_nic(
            firmware,
            # XXX closure over i
            fn -> WorldAffairs.handle_input_request(i) end,
            fn val -> WorldAffairs.handle_output_request(i, val) end
          )
        end
      )

    all_tasks
    |> Enum.map(
      fn t -> Task.await(t, :infinity) end
    )

    # XXX would given IntCode program ever try to read input?
    # XXX better intercept result (i.e. first-ever value Y sent to NIC 255) at TX
    # nic255 =
    #   run_nic(
    #     firmware,
    #     &handle_result/0,
    #     fn _ -> raise RuntimeError, message: "result collector does not emit octets" end
    #   )
  end

  @spec run_nic([integer], (-> integer), (integer -> :ok)) :: Task.t()
  defp run_nic(firmware, input_fun, output_fun) do
    task = Task.async(
      IntCodeBoost,
      :execute,
      [
        firmware,
        # both (in/out) from perspective of IntCode machine
        input_fun,
        output_fun
      ]
    )
  end
end
